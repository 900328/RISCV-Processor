SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

export PKG_SRCS =
export HDL_SRCS = $(shell find $(PWD)/../hdl -name '*.sv')
export SRAM_LIB =
export DESIGN_TOP = loop

.PHONY: lint
lint: clean
	mkdir -p reports
	sg_shell < lint.tcl |& tee reports/lint.log
	mv spyglass-1/consolidated_reports/*_lint_lint_turbo_rtl/*.rpt reports/
	mv reports/moresimple_turbo.rpt reports/lint.rpt
	rm -rf spyglass-1 WORK *.log
	bash check_lint_error.sh

.PHONY: clean
clean:
	rm -rf spyglass-1 WORK *.log reports
