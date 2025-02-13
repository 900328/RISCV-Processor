.section .data
memory_location:
_start:


ADDI x1, x0, 16        # x1 = 10                    # PC = 0x1eceb000
ADDI x2, x0, 20        # x2 = 20                    # PC = 0x1eceb004
SW x2, 0(x1)              # PC = 0x1eceb008
LW x3, 0(x1)                   # PC = 0x1eceb00c
# Load data hazard: 
ADD x4, x3, x2         # x4 = x3 + x2 = 20 + 20 = 40  # PC = 0x1eceb010
SUB x5, x4, x3         # x5 = x3 - x1 = 20 - 10 = 10  # PC = 0x1eceb014
ANDI x6, x5, 155         # x6 = x3 & x2 = 20 & 20 = 20  # PC = 0x1eceb018
OR x7, x6, x1          # x7 = x3 | x1 = 20 | 10 = 30  # PC = 0x1eceb01c




slti x0, x0, -256 # this is the magic instruction to end the simulation
