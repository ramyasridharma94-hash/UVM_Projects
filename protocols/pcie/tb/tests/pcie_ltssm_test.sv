`ifndef PCIE_LTSSM_TEST_SV
`define PCIE_LTSSM_TEST_SV

// LTSSM test — link training, speed changes, recovery, loopback, disable/enable
class pcie_ltssm_test extends pcie_base_test;
  `uvm_component_utils(pcie_ltssm_test)
  import pcie_pkg::*;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_ltssm_seq  ltssm_seq;
    pcie_mem_wr_seq wr_seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== LTSSM Training & Recovery Test ===", UVM_LOW)

    // Scenario 1: Link training only
    ltssm_seq = pcie_ltssm_seq::type_id::create("train");
    ltssm_seq.scenario = pcie_ltssm_seq::LTSSM_TRAIN_ONLY;
    ltssm_seq.start(env.agent.sequencer);

    // Normal traffic on stable L0 link
    wr_seq = pcie_mem_wr_seq::type_id::create("wr_l0");
    wr_seq.num_pkts = 8;
    wr_seq.start(env.agent.sequencer);

    // Scenario 2: Speed change Gen1 → Gen3
    ltssm_seq = pcie_ltssm_seq::type_id::create("speed_chg");
    ltssm_seq.scenario = pcie_ltssm_seq::LTSSM_SPEED_CHANGE;
    ltssm_seq.start(env.agent.sequencer);

    // More traffic at Gen3 speed
    wr_seq = pcie_mem_wr_seq::type_id::create("wr_gen3");
    wr_seq.use_64bit = 1; wr_seq.num_pkts = 8;
    wr_seq.start(env.agent.sequencer);

    // Scenario 3: Recovery via framing error
    ltssm_seq = pcie_ltssm_seq::type_id::create("recovery");
    ltssm_seq.scenario = pcie_ltssm_seq::LTSSM_RECOVERY;
    ltssm_seq.start(env.agent.sequencer);

    // Post-recovery traffic
    wr_seq = pcie_mem_wr_seq::type_id::create("wr_post_recov");
    wr_seq.num_pkts = 4;
    wr_seq.start(env.agent.sequencer);

    // Scenario 4: Loopback
    ltssm_seq = pcie_ltssm_seq::type_id::create("loopback");
    ltssm_seq.scenario = pcie_ltssm_seq::LTSSM_LOOPBACK;
    ltssm_seq.start(env.agent.sequencer);

    // Scenario 5: Disable/Enable
    ltssm_seq = pcie_ltssm_seq::type_id::create("dis_en");
    ltssm_seq.scenario = pcie_ltssm_seq::LTSSM_DISABLE_ENABLE;
    ltssm_seq.start(env.agent.sequencer);

    #500ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_ltssm_test

`endif
