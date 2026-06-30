TESTNAME      ?= bridge_write_test
UVM_VERBOSITY ?= UVM_LOW
SEED          ?= 1
PCIE_PKG       = ../../../protocols/pcie/rtl/pcie_pkg.sv
RTL_DIR        = ../rtl
TB_DIR         = ../tb

INC_DIRS = +incdir+$(TB_DIR)/master_agent +incdir+$(TB_DIR)/slave_agent \
           +incdir+$(TB_DIR)/sequences    +incdir+$(TB_DIR)/env \
           +incdir+$(TB_DIR)/tests

SRC_FILES = $(PCIE_PKG) $(RTL_DIR)/pcie_to_axi4_bridge.sv \
            $(TB_DIR)/interface/pcie_tlp_if.sv \
            $(TB_DIR)/interface/axi4_if.sv \
            $(TB_DIR)/master_agent/pcie_tlp_agent_pkg.sv \
            $(TB_DIR)/top/tb_top.sv

VCS_FLAGS = -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2 \
            $(INC_DIRS) +define+UVM_NO_DEPRECATED -l compile.log
SIM_FLAGS = +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(UVM_VERBOSITY) \
            -l sim_$(TESTNAME).log +ntb_random_seed=$(SEED)

.PHONY: all compile run clean regress write read cfg mixed

all: compile run
compile:
	vcs $(VCS_FLAGS) $(SRC_FILES) -o simv
run:
	./simv $(SIM_FLAGS)
write:  compile; $(MAKE) run TESTNAME=bridge_write_test
read:   compile; $(MAKE) run TESTNAME=bridge_read_test
cfg:    compile; $(MAKE) run TESTNAME=bridge_cfg_test
mixed:  compile; $(MAKE) run TESTNAME=bridge_mixed_test
regress: compile
	$(MAKE) run TESTNAME=bridge_write_test
	$(MAKE) run TESTNAME=bridge_read_test
	$(MAKE) run TESTNAME=bridge_cfg_test
	$(MAKE) run TESTNAME=bridge_mixed_test
clean:
	rm -rf simv simv.daidir csrc *.log *.vpd *.vdb *.vcd DVEfiles ucli.key
