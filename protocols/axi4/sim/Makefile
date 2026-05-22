##############################################################
# AXI4 UVM Simulation Makefile (VCS)
##############################################################

TESTNAME      ?= axi4_write_test
UVM_VERBOSITY ?= UVM_LOW
UVM_HOME      ?= $(VCS_HOME)/etc/uvm-1.2
SEED          ?= 1

TB_TOP    = tb_top
SIM_DIR   = $(PWD)
RTL_DIR   = ../rtl
TB_DIR    = ../tb
INC_DIRS  = +incdir+$(TB_DIR)/agent \
            +incdir+$(TB_DIR)/sequences \
            +incdir+$(TB_DIR)/env \
            +incdir+$(TB_DIR)/tests

SRC_FILES = $(RTL_DIR)/axi4_slave.sv              \
            $(TB_DIR)/interface/axi4_if.sv         \
            $(TB_DIR)/agent/axi4_agent_pkg.sv      \
            $(TB_DIR)/top/tb_top.sv

VCS_FLAGS = -full64 -sverilog -timescale=1ns/1ps  \
            -ntb_opts uvm-1.2                      \
            $(INC_DIRS)                            \
            +define+UVM_NO_DEPRECATED              \
            -l compile.log

SIM_FLAGS = +UVM_TESTNAME=$(TESTNAME)             \
            +UVM_VERBOSITY=$(UVM_VERBOSITY)        \
            -l sim_$(TESTNAME).log                 \
            +ntb_random_seed=$(SEED)

.PHONY: all compile run clean regress

all: compile run

compile:
	vcs $(VCS_FLAGS) $(SRC_FILES) -o simv

run:
	./simv $(SIM_FLAGS)

run_write:
	$(MAKE) run TESTNAME=axi4_write_test

run_read:
	$(MAKE) run TESTNAME=axi4_read_test

run_burst:
	$(MAKE) run TESTNAME=axi4_burst_test

regress: compile
	$(MAKE) run_write
	$(MAKE) run_read
	$(MAKE) run_burst

clean:
	rm -rf simv simv.daidir csrc *.log *.vpd *.vdb DVEfiles ucli.key

wave:
	vcs $(VCS_FLAGS) $(SRC_FILES) -o simv -debug_all
	./simv $(SIM_FLAGS) -gui
