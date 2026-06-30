// PCIe UVM Agent Package — compile-order wrapper
package pcie_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import pcie_pkg::*;

  `include "pcie_tlp_seq_item.sv"
  `include "pcie_dllp_seq_item.sv"
  `include "pcie_sequencer.sv"
  `include "pcie_driver.sv"
  `include "pcie_monitor.sv"
  `include "pcie_agent.sv"

  // sequences
  `include "pcie_base_seq.sv"
  `include "pcie_mem_rd_seq.sv"
  `include "pcie_mem_wr_seq.sv"
  `include "pcie_cfg_rd_seq.sv"
  `include "pcie_cfg_wr_seq.sv"
  `include "pcie_msg_seq.sv"
  `include "pcie_cpl_seq.sv"
  `include "pcie_err_seq.sv"
  `include "pcie_pm_seq.sv"
  `include "pcie_msi_seq.sv"
  `include "pcie_fc_seq.sv"
  `include "pcie_atomicop_seq.sv"
  `include "pcie_ltssm_seq.sv"

  // env
  `include "pcie_scoreboard.sv"
  `include "pcie_coverage.sv"
  `include "pcie_env.sv"

  // tests
  `include "pcie_base_test.sv"
  `include "pcie_mem_access_test.sv"
  `include "pcie_cfg_access_test.sv"
  `include "pcie_error_test.sv"
  `include "pcie_pm_test.sv"
  `include "pcie_msi_test.sv"
  `include "pcie_fc_test.sv"
  `include "pcie_ltssm_test.sv"
  `include "pcie_atomicop_test.sv"
  `include "pcie_virtual_ch_test.sv"

endpackage : pcie_agent_pkg
