`ifndef PCIE_MSI_TEST_SV
`define PCIE_MSI_TEST_SV

// MSI/MSI-X test — programs capability registers and fires interrupt vectors
class pcie_msi_test extends pcie_base_test;
  `uvm_component_utils(pcie_msi_test)
  import pcie_pkg::*;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_msi_seq msi_seq;
    pcie_cfg_rd_seq rd_seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== MSI/MSI-X Interrupt Test ===", UVM_LOW)

    // Read MSI capability before enabling
    rd_seq = pcie_cfg_rd_seq::type_id::create("cap_rd");
    rd_seq.type1    = 0;
    rd_seq.num_pkts = 3;
    rd_seq.start(env.agent.sequencer);

    // MSI test (single vector)
    msi_seq = pcie_msi_seq::type_id::create("msi_1v");
    msi_seq.use_msix    = 0;
    msi_seq.num_vectors = 1;
    msi_seq.start(env.agent.sequencer);

    // MSI test (8 vectors)
    msi_seq = pcie_msi_seq::type_id::create("msi_8v");
    msi_seq.use_msix    = 0;
    msi_seq.num_vectors = 8;
    msi_seq.start(env.agent.sequencer);

    // MSI-X test (32 vectors)
    msi_seq = pcie_msi_seq::type_id::create("msix_32v");
    msi_seq.use_msix    = 1;
    msi_seq.num_vectors = 32;
    msi_seq.start(env.agent.sequencer);

    // Legacy INTx (assert/deassert)
    begin
      pcie_msg_seq intx_seq;
      intx_seq = pcie_msg_seq::type_id::create("inta_assert");
      intx_seq.msg_sel  = pcie_msg_seq::MSG_ASSERT_INTA;
      intx_seq.num_pkts = 2;
      intx_seq.start(env.agent.sequencer);
      intx_seq = pcie_msg_seq::type_id::create("inta_deassert");
      intx_seq.msg_sel  = pcie_msg_seq::MSG_DEASSERT_INTA;
      intx_seq.num_pkts = 2;
      intx_seq.start(env.agent.sequencer);
    end

    #300ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_msi_test

`endif
