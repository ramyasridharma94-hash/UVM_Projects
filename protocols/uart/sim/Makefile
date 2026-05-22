TESTNAME      ?= uart_single_test
UVM_VERBOSITY ?= UVM_LOW
SEED          ?= 1
RTL_DIR       = ../rtl
TB_DIR        = ../tb
INC_DIRS      = +incdir+$(TB_DIR)/agent +incdir+$(TB_DIR)/sequences \
                +incdir+$(TB_DIR)/env   +incdir+$(TB_DIR)/tests
SRC_FILES     = $(RTL_DIR)/uart_tx.sv             \
                $(RTL_DIR)/uart_rx.sv             \
                $(RTL_DIR)/uart_top.sv            \
                $(TB_DIR)/interface/uart_if.sv    \
                $(TB_DIR)/agent/uart_agent_pkg.sv \
                $(TB_DIR)/top/tb_top.sv
VCS_FLAGS     = -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2 \
                $(INC_DIRS) +define+UVM_NO_DEPRECATED -l compile.log
SIM_FLAGS     = +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(UVM_VERBOSITY) \
                -l sim_$(TESTNAME).log +ntb_random_seed=$(SEED)
.PHONY: all compile run clean regress
all: compile run
compile: ; vcs $(VCS_FLAGS) $(SRC_FILES) -o simv
run:     ; ./simv $(SIM_FLAGS)
regress: compile
	$(MAKE) run TESTNAME=uart_single_test
	$(MAKE) run TESTNAME=uart_multi_test
clean:   ; rm -rf simv simv.daidir csrc *.log *.vpd *.vdb DVEfiles ucli.key
