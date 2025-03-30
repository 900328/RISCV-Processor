#!/usr/bin/python3

import sys
import os
import pathlib
import subprocess
import re

if len(sys.argv) != 2:
    print("elf2bt9.py [elf file]")
    exit(1)

objdump="riscv64-unknown-elf-objdump"

own_path = os.path.abspath(__file__)
script_dir = os.path.dirname(own_path)
sim_dir = os.path.join(script_dir, "../sim")
work_dir = os.path.join(script_dir, "../sim/bin")
spike_dir = os.path.join(script_dir, "../sim/spike")

in_file = sys.argv[1]
dis_file = os.path.join(work_dir, pathlib.Path(in_file).stem + ".dis")
log_file = os.path.join(spike_dir, "spike.log")
bt9_file = os.path.join(work_dir, pathlib.Path(in_file).stem + ".bt9.trace")

if not os.path.isdir(work_dir):
    os.system(f"mkdir -p {work_dir}")

result = subprocess.run(f"{objdump} -h {in_file}", shell=True, stdout=subprocess.PIPE)
if result.returncode != 0:
    print("objdump failed")
    exit(1)
sections_raw = result.stdout.decode().splitlines()[5:]
sections = []
for i in range(0, len(sections_raw), 2):
    if "CODE" in sections_raw[i+1]:
        sections.append(sections_raw[i].strip().split()[1])

result = subprocess.run(f"{objdump} -D -Mnumeric -j {' -j '.join(sections)} {in_file} > {dis_file}", shell=True)
if result.returncode != 0:
    print("objdump failed")
    exit(1)

branch_list = {}

with open(dis_file) as f:
    for l in f.readlines():
        m = re.search("^([ 0-9a-f]{8}):\t([0-9a-f]{8}) +\t(.+)", l)
        if m is not None:
            pc = int(m.group(1), 16)
            inst = int(m.group(2), 16)
            mnemonic = m.group(3)
            if inst & 0x7f in [0x63, 0x67, 0x6f]:
                m = re.search(".*(,|# )([0-9a-f]+) <.*", mnemonic)
                if m is not None:
                    target = int(m.group(2), 16)
                    assert(target != pc + 4)
                else:
                    target = None
                if inst & 0x7f == 0x63:
                    bclass = " JMP+DIR+CND"
                if inst & 0x7f == 0x67:
                    if mnemonic == "ret":
                        bclass = " RET+IND+UCD"
                    elif '<' in mnemonic:
                        bclass = "CALL+IND+UCD"
                    else:
                        bclass = " JMP+IND+UCD"
                if inst & 0x7f == 0x6f:
                    bclass = " JMP+DIR+UCD"
                branch_list[pc] = [0, inst, target, bclass, 0, 0, 1, mnemonic]

result = subprocess.run(f"make spike ELF={in_file}", shell=True, cwd=sim_dir, stdout=subprocess.PIPE)
if result.returncode != 0:
    print("spike failed")
    exit(1)

edge_list = {}
total_branch_count = 0

with open(log_file) as f:
    ll = f.readlines()
    i = 0
    while True:
        lc3 = ll[i].strip().split()
        pc3 = int(lc3[3][2:], 16)
        if pc3 in branch_list:
            break
        i += 1
    while i < len(ll)-1:
        lc = ll[i].strip().split()
        ln = ll[i+1].strip().split()
        pc =      int(lc[3][2:], 16)
        pc_next = int(ln[3][2:], 16)
        if pc in branch_list:
            total_branch_count += 1
            if branch_list[pc][2] is None:
                taken = True
                branch_list[pc][2] = [pc_next, ]
                branch_list[pc][6] = 1
            elif isinstance(branch_list[pc][2], list):
                taken = True
                if pc_next not in branch_list[pc][2]:
                    branch_list[pc][2].append(pc_next)
                    branch_list[pc][6] += 1
            else:
                taken = pc_next == branch_list[pc][2]

            if taken:
                branch_list[pc][4] += 1
            else:
                branch_list[pc][5] += 1

            inst_count = 1
            while True:
                if i+inst_count >= len(ll):
                    pc2 = None
                    break
                lc2 = ll[i+inst_count].strip().split()
                pc2 = int(lc2[3][2:], 16)
                if pc2 in branch_list:
                    break
                inst_count += 1

            if (pc, pc_next) not in edge_list:
                edge_list[(pc, pc_next)] = [0, taken, pc2, inst_count-1, 1]
            else:
                edge_list[(pc, pc_next)][4] += 1

            i += inst_count

for b in list(branch_list):
    if isinstance(branch_list[b][2], list):
        if len(branch_list[b][2]) == 1:
            branch_list[b][2] = branch_list[b][2][0]
    if branch_list[b][2] is None:
        branch_list.pop(b, None)
        continue
    if branch_list[b][4] == 0 and branch_list[b][5] == 0:
        branch_list.pop(b, None)
        continue

b_id = 1
for b in branch_list:
    branch_list[b][0] = b_id
    b_id += 1

e_id = 1
for e in edge_list:
    edge_list[e][0] = e_id
    e_id += 1

with open(bt9_file, 'w') as f:
    f.write(f"BT9_SPA_TRACE_FORMAT\n")
    f.write(f"bt9_minor_version: 0\n")
    f.write(f"has_physical_address: 0\n")
    f.write(f"md5_checksum:\n")
    f.write(f"conversion_date:\n")
    f.write(f"original_stf_input_file:\n")
    f.write(f"total_instruction_count: {len(ll):>16d}\n")
    f.write(f"branch_instruction_count: {total_branch_count:>16d}\n")
    f.write(f"invalid_physical_branch_target_count:                0\n")
    f.write(f"A32_instruction_count: {len(ll):>16d}\n")
    f.write(f"A64_instruction_count:                0\n")
    f.write(f"T32_instruction_count:                0\n")
    f.write(f"unidentified_instruction_count:                0\n")
    f.write(f"BT9_NODES\n")
    f.write(f"#NODE  id virtual_address physical_address     opcode size\n")
    f.write(f"NODE    0               0                -          0    0\n")
    for b in branch_list:
        f.write(f"NODE {branch_list[b][0]:>4d}      0x{b:08x}                - 0x{branch_list[b][1]:08x}    4 class: {branch_list[b][3]} behavior: ")
        if branch_list[b][4] == 0:
            f.write("ANT+")
        elif branch_list[b][5] == 0:
            f.write(" AT+")
        else:
            f.write("DYN+")
        if branch_list[b][6] == 0:
            f.write("DIR")
        else:
            f.write("IND")
        f.write(f' taken_cnt: {branch_list[b][4]:>8d} not_taken_cnt: {branch_list[b][5]:>8d} tgt_cnt: {branch_list[b][6]:>3d} # mnemonic: "{branch_list[b][7]}"\n')
    f.write(f"BT9_EDGES\n")
    f.write(f"#EDGE  id src_id dest_id taken br_virt_target br_phy_target inst_cnt\n")
    f.write(f"EDGE    0      0       1     N              0             -        0 traverse_cnt:        1\n")
    for e in edge_list:
        src_id = branch_list[e[0]][0]
        if edge_list[e][2] is None:
            dest_id = 0
        else:
            dest_id = branch_list[edge_list[e][2]][0]
        f.write(f"EDGE {edge_list[e][0]:>4d}   {src_id:>4d}    {dest_id:>4d}     ")
        if edge_list[e][1]:
            f.write(f"T")
        else:
            f.write(f"N")
        f.write(f"     0x{e[1]:>8x}             - {edge_list[e][3]:>8d} traverse_cnt: {edge_list[e][4]:>8d}\n")
    f.write(f"BT9_EDGE_SEQUENCE\n")
    f.write(f"0\n")
    i = 0
    while True:
        lc3 = ll[i].strip().split()
        pc3 = int(lc3[3][2:], 16)
        if pc3 in branch_list:
            break
        i += 1
    while i < len(ll)-1:
        lc = ll[i].strip().split()
        ln = ll[i+1].strip().split()
        pc =      int(lc[3][2:], 16)
        pc_next = int(ln[3][2:], 16)
        if pc in branch_list:
            inst_count = 1
            while True:
                if i+inst_count >= len(ll):
                    break
                lc2 = ll[i+inst_count].strip().split()
                pc2 = int(lc2[3][2:], 16)
                if pc2 in branch_list:
                    break
                inst_count += 1
            f.write(f"{edge_list[(pc, pc_next)][0]:d}\n")
            i += inst_count
    f.write(f"EOF\n")
