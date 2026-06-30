`ifndef PCIE_PM_TEST_SV
`define PCIE_PM_TEST_SV

// Power Management test — L0s, L1, D3hot transitions, PME, ASPM
class pcie_pm_test extends pcie_base_test;
  `uvm_component_utils(pcie_pm_test)
  import pcie_pkg::*;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_mem_wr_seq wr_seq;
    pcie_pm_seq     pm_seq;
    pcie_msg_seq    msg_seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== Power Management Test ===", UVM_LOW)

    // Normal traffic before PM
    wr_seq = pcie_mem_wr_seq::type_id::create("pre_pm_wr");
    wr_seq.num_pkts = 8;
    wr_seq.start(env.agent.sequencer);

    // ASPM L1 entry/exit sequence
    pm_seq = pcie_pm_seq::type_id::create("pm_l1");
    pm_seq.start(env.agent.sequencer);

    // PME message
    msg_seq = pcie_msg_seq::type_id::create("pme_msg");
    msg_seq.msg_sel  = pcie_msg_seq::MSG_PME;
    msg_seq.num_pkts = 1;
    msg_seq.start(env.agent.sequencer);

    // PME_TO_ACK
    msg_seq = pcie_msg_seq::type_id::create("pme_to_ack");
    msg_seq.msg_sel  = pcie_msg_seq::MSG_PME_TO_ACK;
    msg_seq.num_pkts = 1;
    msg_seq.start(env.agent.sequencer);

    // Recovery after PM
    wr_seq = pcie_mem_wr_seq::type_id::create("post_pm_wr");
    wr_seq.num_pkts = 8;
    wr_seq.start(env.agent.sequencer);

    #300ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_pm_test

`endif
