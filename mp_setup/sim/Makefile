SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

PKG_SRCS  :=
HDL_SRCS  := $(shell find $(PWD)/../hdl -name '*.sv')
COMM_HVL  :=
VCS_HVL   := $(COMM_HVL) $(shell find $(PWD)/../hvl/vcs -name '*.sv' -o -name '*.v')
VER_HVL   :=
SRAM_SRCS :=
HDRS      :=
DW_IP     :=
VCS_SRCS  := $(PKG_SRCS) $(HDL_SRCS) $(VCS_HVL) $(SRAM_SRCS) $(DW_IP)
VER_SRCS  := $(PKG_SRCS) $(HDL_SRCS) $(VER_HVL) $(SRAM_SRCS) $(DW_IP)

export VCS_ARCH_OVERRIDE=linux
VCS_FLAGS= -full64 -lca -sverilog -timescale=1ps/1ps -debug_acc+all -kdb -fsdb -suppress=LCA_FEATURES_ENABLED -msg_config=../vcs_warn.config +incdir+$(DW)/sim_ver +define+DW_SUPPRESS_WARN

vcs/top_tb: $(VCS_SRCS) $(HDRS)
	mkdir -p vcs
	python3 check_sus.py
	cd vcs && vcs $(VCS_SRCS) $(VCS_FLAGS) -l compile.log -top top_tb -o top_tb
	bash check_compile_error.sh

.PHONY: run_vcs_top_tb
run_vcs_top_tb: vcs/top_tb
	rm -f vcs/dump.fsdb
	cd vcs && ./top_tb -l simulation.log -exitstatus
	bash check_sim_error.sh

.PHONY: verdi
verdi:
	mkdir -p verdi
	cd verdi && timeout $(ECE411_GUI_TIMEOUT) $(VERDI_HOME)/bin/verdi -ssf $(PWD)/vcs/dump.fsdb

.PHONY: clean
clean:
	rm -rf bin vcs verdi verilator
