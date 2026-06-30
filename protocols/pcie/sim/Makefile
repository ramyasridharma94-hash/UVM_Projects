TESTNAME      ?= pcie_mem_access_test
UVM_VERBOSITY ?= UVM_LOW
SEED          ?= 1

RTL_DIR        = ../rtl
TB_DIR         = ../tb

INC_DIRS = +incdir+$(TB_DIR)/agent \
           +incdir+$(TB_DIR)/sequences \
           +incdir+$(TB_DIR)/env \
           +incdir+$(TB_DIR)/tests

SRC_FILES = $(RTL_DIR)/pcie_pkg.sv              \
            $(RTL_DIR)/pcie_phy.sv              \
            $(RTL_DIR)/pcie_dll.sv              \
            $(RTL_DIR)/pcie_tlp_tx.sv           \
            $(RTL_DIR)/pcie_tlp_rx.sv           \
            $(RTL_DIR)/pcie_top.sv              \
            $(TB_DIR)/interface/pcie_if.sv      \
            $(TB_DIR)/agent/pcie_agent_pkg.sv   \
            $(TB_DIR)/top/tb_top.sv

VCS_FLAGS = -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2 \
            $(INC_DIRS) +define+UVM_NO_DEPRECATED -l compile.log

SIM_FLAGS = +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(UVM_VERBOSITY) \
            -l sim_$(TESTNAME).log +ntb_random_seed=$(SEED)

.PHONY: all compile run clean regress

all: compile run

compile:
	vcs $(VCS_FLAGS) $(SRC_FILES) -o simv

run:
	./simv $(SIM_FLAGS)

# Full regression — all tests
regress: compile
	$(MAKE) run TESTNAME=pcie_mem_access_test
	$(MAKE) run TESTNAME=pcie_cfg_access_test
	$(MAKE) run TESTNAME=pcie_error_test
	$(MAKE) run TESTNAME=pcie_pm_test
	$(MAKE) run TESTNAME=pcie_msi_test
	$(MAKE) run TESTNAME=pcie_fc_test
	$(MAKE) run TESTNAME=pcie_ltssm_test
	$(MAKE) run TESTNAME=pcie_atomicop_test
	$(MAKE) run TESTNAME=pcie_virtual_ch_test

# Individual test targets for convenience
mem:    compile; $(MAKE) run TESTNAME=pcie_mem_access_test
cfg:    compile; $(MAKE) run TESTNAME=pcie_cfg_access_test
err:    compile; $(MAKE) run TESTNAME=pcie_error_test
pm:     compile; $(MAKE) run TESTNAME=pcie_pm_test
msi:    compile; $(MAKE) run TESTNAME=pcie_msi_test
fc:     compile; $(MAKE) run TESTNAME=pcie_fc_test
ltssm:  compile; $(MAKE) run TESTNAME=pcie_ltssm_test
atomic: compile; $(MAKE) run TESTNAME=pcie_atomicop_test
vc:     compile; $(MAKE) run TESTNAME=pcie_virtual_ch_test

# Seed sweep (10 seeds) for a given test
SEEDS = 1 2 3 4 5 6 7 8 9 10
seed_sweep:
	@for s in $(SEEDS); do \
	    $(MAKE) run TESTNAME=$(TESTNAME) SEED=$$s; \
	done

clean:
	rm -rf simv simv.daidir csrc *.log *.vpd *.vdb *.vcd DVEfiles ucli.key
