SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

PKG_SRCS  := $(PWD)/../pkg/types.sv
HDL_SRCS  := $(shell find $(PWD)/../hdl -name '*.sv')
COMM_HVL  := $(shell find $(PWD)/../hvl/common -name '*.sv' -o -name '*.v')
VCS_HVL   := $(COMM_HVL) $(shell find $(PWD)/../hvl/vcs -name '*.sv' -o -name '*.v')
VER_HVL   :=
SRAM_SRCS :=
HDRS      := $(shell find $(PWD)/../hvl -name '*.svh')
DW_IP     :=
VCS_SRCS  := $(PKG_SRCS) $(HDL_SRCS) $(VCS_HVL) $(SRAM_SRCS) $(DW_IP)
VER_SRCS  := $(PKG_SRCS) $(HDL_SRCS) $(VER_HVL) $(SRAM_SRCS) $(DW_IP)

export VCS_ARCH_OVERRIDE=linux
VCS_FLAGS= -full64 -lca -sverilog -timescale=1ps/1ps -debug_acc+all -kdb -fsdb -suppress=LCA_FEATURES_ENABLED -msg_config=../vcs_warn.config +incdir+$(DW)/sim_ver +define+DW_SUPPRESS_WARN

vcs/top_tb: $(VCS_SRCS) $(HDRS)
	mkdir -p vcs
	python3 check_sus.py
	python3 ../bin/rvfi_reference.py
	cd vcs && vcs $(VCS_SRCS) $(VCS_FLAGS) -l compile.log -top top_tb -o top_tb
	bash check_compile_error.sh

.PHONY: run_vcs_top_tb
run_vcs_top_tb: vcs/top_tb $(PROG)
	mkdir -p spike
	python3 ../bin/generate_memory_file.py -4 $(PROG)
	rm -f vcs/dump.fsdb
	export ECE411_CLOCK_PERIOD_PS=2000 ;\
	export ECE411_MEMFILE=$(PWD)/bin/memory ;\
	cd vcs && ./top_tb -l simulation.log -exitstatus
	bash check_sim_error.sh

.PHONY: covrep
covrep: vcs/top_tb.vdb
	cd vcs && urg -dir top_tb.vdb

.PHONY: verdi
verdi:
	mkdir -p verdi
	cd verdi && timeout $(ECE411_GUI_TIMEOUT) $(VERDI_HOME)/bin/verdi -ssf $(PWD)/vcs/dump.fsdb

.PHONY: spike
spike: $(ELF)
	mkdir -p spike
	spike --isa=rv32imc -m0x1eceb000:0xe1315000 --log-commits $(ELF) |& tail -n +6 > spike/spike.log

.PHONY: interactive_spike
interactive_spike: $(ELF)
	spike --isa=rv32imc -m0x1eceb000:0xe1315000 --log-commits -d $(ELF)

.PHONY: clean
clean:
	rm -rf bin vcs verdi verilator spike
