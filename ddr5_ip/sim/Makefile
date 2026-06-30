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

# Compile order: pkg → ctrl submodules → ctrl_top → phy submodules → phy_top → ip_top
SRC_FILES = \
  $(DDR5_PROTO)/rtl/ddr5_pkg.sv              \
  $(RTL_DIR)/ctrl/ddr5_axi4_slave.sv         \
  $(RTL_DIR)/ctrl/ddr5_addr_mapper.sv        \
  $(RTL_DIR)/ctrl/ddr5_wr_data_buf.sv        \
  $(RTL_DIR)/ctrl/ddr5_rd_data_buf.sv        \
  $(RTL_DIR)/ctrl/ddr5_bank_fsm.sv           \
  $(RTL_DIR)/ctrl/ddr5_cmd_scheduler.sv      \
  $(RTL_DIR)/ctrl/ddr5_refresh_ctrl.sv       \
  $(RTL_DIR)/ctrl/ddr5_zq_ctrl.sv            \
  $(RTL_DIR)/ctrl/ddr5_ecc.sv                \
  $(RTL_DIR)/ctrl/ddr5_init_fsm.sv           \
  $(RTL_DIR)/ctrl/ddr5_mode_reg_ctrl.sv      \
  $(RTL_DIR)/ctrl/ddr5_power_ctrl.sv         \
  $(RTL_DIR)/ctrl/ddr5_cmd_arbiter.sv        \
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
            $(INC_DIRS) +define+UVM_NO_DEPRECATED \
            +define+DDR5_IP_TOP \
            -l compile.log

SIM_FLAGS = +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(UVM_VERBOSITY) \
            -l sim_$(TESTNAME).log +ntb_random_seed=$(SEED)

.PHONY: all compile run clean regress lint write read refresh mrs train pm err lp5

all: compile run

compile:
	vcs $(VCS_FLAGS) $(SRC_FILES) -o simv 2>&1 | tee compile.log

run:
	./simv $(SIM_FLAGS)

# Lint-only check (no simulation)
lint:
	vcs $(VCS_FLAGS) $(SRC_FILES) -lint -o /dev/null 2>&1 | tee lint.log
	@echo "Lint complete — check lint.log"

# Individual test targets
write:   compile; $(MAKE) run TESTNAME=ddr5_write_test
read:    compile; $(MAKE) run TESTNAME=ddr5_read_test
refresh: compile; $(MAKE) run TESTNAME=ddr5_refresh_test
mrs:     compile; $(MAKE) run TESTNAME=ddr5_mrs_test
train:   compile; $(MAKE) run TESTNAME=ddr5_train_test
pm:      compile; $(MAKE) run TESTNAME=ddr5_pm_test
err:     compile; $(MAKE) run TESTNAME=ddr5_err_test
lp5:     compile; $(MAKE) run TESTNAME=ddr5_lpddr5_test

# Full regression suite
regress: compile
	@echo "=== DDR5 IP Regression ==="
	$(MAKE) run TESTNAME=ddr5_write_test
	$(MAKE) run TESTNAME=ddr5_read_test
	$(MAKE) run TESTNAME=ddr5_refresh_test
	$(MAKE) run TESTNAME=ddr5_mrs_test
	$(MAKE) run TESTNAME=ddr5_train_test
	$(MAKE) run TESTNAME=ddr5_pm_test
	$(MAKE) run TESTNAME=ddr5_err_test
	$(MAKE) run TESTNAME=ddr5_lpddr5_test
	@echo "=== Regression Complete ==="

# Seed sweep for coverage closure
seed_sweep:
	@for s in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do \
	    echo "--- Seed $$s ---"; \
	    $(MAKE) run TESTNAME=$(TESTNAME) SEED=$$s; \
	done

clean:
	rm -rf simv simv.daidir csrc *.log *.vpd *.vdb *.vcd DVEfiles ucli.key
