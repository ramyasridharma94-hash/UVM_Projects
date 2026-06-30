TESTNAME      ?= ddr5_write_test
UVM_VERBOSITY ?= UVM_LOW
SEED          ?= 1
RTL_DIR        = ../rtl
TB_DIR         = ../tb

INC_DIRS = +incdir+$(TB_DIR)/agent    \
           +incdir+$(TB_DIR)/sequences \
           +incdir+$(TB_DIR)/env       \
           +incdir+$(TB_DIR)/tests

SRC_FILES = $(RTL_DIR)/ddr5_pkg.sv               \
            $(RTL_DIR)/ddr5_phy.sv               \
            $(RTL_DIR)/ddr5_ctrl.sv              \
            $(RTL_DIR)/ddr5_top.sv               \
            $(TB_DIR)/interface/ddr5_if.sv       \
            $(TB_DIR)/interface/dfi_if.sv        \
            $(TB_DIR)/agent/ddr5_agent_pkg.sv    \
            $(TB_DIR)/top/tb_top.sv

VCS_FLAGS = -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2 \
            $(INC_DIRS) +define+UVM_NO_DEPRECATED -l compile.log

SIM_FLAGS = +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(UVM_VERBOSITY) \
            -l sim_$(TESTNAME).log +ntb_random_seed=$(SEED)

.PHONY: all compile run clean regress write read refresh mrs train pm err lp5

all: compile run
compile:
	vcs $(VCS_FLAGS) $(SRC_FILES) -o simv
run:
	./simv $(SIM_FLAGS)

write:   compile; $(MAKE) run TESTNAME=ddr5_write_test
read:    compile; $(MAKE) run TESTNAME=ddr5_read_test
refresh: compile; $(MAKE) run TESTNAME=ddr5_refresh_test
mrs:     compile; $(MAKE) run TESTNAME=ddr5_mrs_test
train:   compile; $(MAKE) run TESTNAME=ddr5_train_test
pm:      compile; $(MAKE) run TESTNAME=ddr5_pm_test
err:     compile; $(MAKE) run TESTNAME=ddr5_err_test
lp5:     compile; $(MAKE) run TESTNAME=ddr5_lpddr5_test

regress: compile
	$(MAKE) run TESTNAME=ddr5_write_test
	$(MAKE) run TESTNAME=ddr5_read_test
	$(MAKE) run TESTNAME=ddr5_refresh_test
	$(MAKE) run TESTNAME=ddr5_mrs_test
	$(MAKE) run TESTNAME=ddr5_train_test
	$(MAKE) run TESTNAME=ddr5_pm_test
	$(MAKE) run TESTNAME=ddr5_err_test
	$(MAKE) run TESTNAME=ddr5_lpddr5_test

seed_sweep:
	@for s in 1 2 3 4 5 6 7 8 9 10; do \
	    $(MAKE) run TESTNAME=$(TESTNAME) SEED=$$s; \
	done

clean:
	rm -rf simv simv.daidir csrc *.log *.vpd *.vdb *.vcd DVEfiles ucli.key
