`ifndef PCIE_FC_TEST_SV
`define PCIE_FC_TEST_SV

// Flow Control test — credit initialization, updates, exhaustion, and recovery
class pcie_fc_test extends pcie_base_test;
  `uvm_component_utils(pcie_fc_test)
  import pcie_pkg::*;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_fc_seq         fc_seq;
    pcie_fc_exhaust_seq exhaust;
    pcie_mem_rd_seq     rd_seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== Flow Control Test ===", UVM_LOW)

    // FC credit stress burst
    fc_seq = pcie_fc_seq::type_id::create("fc_stress");
    fc_seq.burst_count = 32;
    fc_seq.start(env.agent.sequencer);

    // FC credit exhaustion — expect backpressure on req_ready
    exhaust = pcie_fc_exhaust_seq::type_id::create("fc_exhaust");
    exhaust.start(env.agent.sequencer);

    // Recovery reads — should resume after credits are returned
    rd_seq = pcie_mem_rd_seq::type_id::create("fc_recovery_rd");
    rd_seq.num_pkts = 8;
    rd_seq.start(env.agent.sequencer);

    #500ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_fc_test

`endif
