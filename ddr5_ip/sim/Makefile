TESTNAME      ?= ddr5_write_test
UVM_VERBOSITY ?= UVM_LOW
SEED          ?= 1

DDR5_PROTO    = ../../protocols/ddr5
RTL_DIR       = ../rtl
TB_DIR        = $(DDR5_PROTO)/tb

INC_DIRS = +incdir+$(TB_DIR)/agent    \
           +incdir+$(TB_DIR)/sequences \
           +incdir+$(TB_DIR)/env       \
           +incdir+$(TB_DIR)/tests

SRC_FILES = $(DDR5_PROTO)/rtl/ddr5_pkg.sv              \
            $(RTL_DIR)/ctrl/ddr5_cmd_scheduler.sv      \
            $(RTL_DIR)/ctrl/ddr5_bank_fsm.sv           \
            $(RTL_DIR)/ctrl/ddr5_refresh_ctrl.sv       \
            $(RTL_DIR)/ctrl/ddr5_zq_ctrl.sv            \
            $(RTL_DIR)/ctrl/ddr5_ecc.sv                \
            $(RTL_DIR)/ctrl/ddr5_ctrl_top.sv           \
            $(RTL_DIR)/phy/ddr5_dll.sv                 \
            $(RTL_DIR)/phy/ddr5_io_buf.sv              \
            $(RTL_DIR)/phy/ddr5_dfi_ctrl.sv            \
            $(RTL_DIR)/phy/ddr5_phy_top.sv             \
            $(RTL_DIR)/ddr5_ip_top.sv                  \
            $(TB_DIR)/interface/ddr5_if.sv             \
            $(TB_DIR)/interface/dfi_if.sv              \
            $(TB_DIR)/agent/ddr5_agent_pkg.sv          \
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

clean:
	rm -rf simv simv.daidir csrc *.log *.vpd *.vdb *.vcd DVEfiles ucli.key
