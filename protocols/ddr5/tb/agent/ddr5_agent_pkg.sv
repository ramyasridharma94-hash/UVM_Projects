package ddr5_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ddr5_pkg::*;

  `include "ddr5_seq_item.sv"
  `include "ddr5_sequencer.sv"
  `include "ddr5_driver.sv"
  `include "ddr5_monitor.sv"
  `include "ddr5_agent.sv"

  // Sequences
  `include "ddr5_base_seq.sv"
  `include "ddr5_write_seq.sv"
  `include "ddr5_read_seq.sv"
  `include "ddr5_refresh_seq.sv"
  `include "ddr5_mrs_seq.sv"
  `include "ddr5_train_seq.sv"
  `include "ddr5_pm_seq.sv"
  `include "ddr5_err_seq.sv"
  `include "ddr5_lpddr5_seq.sv"

  // Env
  `include "ddr5_scoreboard.sv"
  `include "ddr5_coverage.sv"
  `include "ddr5_env.sv"

  // Tests
  `include "ddr5_base_test.sv"
  `include "ddr5_write_test.sv"
  `include "ddr5_read_test.sv"
  `include "ddr5_refresh_test.sv"
  `include "ddr5_mrs_test.sv"
  `include "ddr5_train_test.sv"
  `include "ddr5_pm_test.sv"
  `include "ddr5_err_test.sv"
  `include "ddr5_lpddr5_test.sv"

endpackage : ddr5_agent_pkg
