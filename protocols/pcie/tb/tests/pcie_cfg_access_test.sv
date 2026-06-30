`ifndef PCIE_CFG_ACCESS_TEST_SV
`define PCIE_CFG_ACCESS_TEST_SV

// Configuration space access test — Type 0 and Type 1, all standard registers
class pcie_cfg_access_test extends pcie_base_test;
  `uvm_component_utils(pcie_cfg_access_test)
  import pcie_pkg::*;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_cfg_rd_seq rd_seq;
    pcie_cfg_wr_seq wr_seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== Configuration Space Test ===", UVM_LOW)

    // Type 0 read sweep
    rd_seq = pcie_cfg_rd_seq::type_id::create("cfgrd0");
    rd_seq.type1    = 0;
    rd_seq.num_pkts = 10;
    rd_seq.start(env.agent.sequencer);

    // Type 1 read sweep (bridge forwarded)
    rd_seq = pcie_cfg_rd_seq::type_id::create("cfgrd1");
    rd_seq.type1    = 1;
    rd_seq.num_pkts = 5;
    rd_seq.start(env.agent.sequencer);

    // Type 0 write (BAR programming)
    wr_seq = pcie_cfg_wr_seq::type_id::create("cfgwr0");
    wr_seq.type1    = 0;
    wr_seq.num_pkts = 5;
    wr_seq.start(env.agent.sequencer);

    // Type 1 write
    wr_seq = pcie_cfg_wr_seq::type_id::create("cfgwr1");
    wr_seq.type1    = 1;
    wr_seq.num_pkts = 3;
    wr_seq.start(env.agent.sequencer);

    // Interleaved read-modify-write
    for (int i = 0; i < 5; i++) begin
      rd_seq = pcie_cfg_rd_seq::type_id::create($sformatf("rmw_rd_%0d", i));
      rd_seq.type1    = 0; rd_seq.num_pkts = 1;
      rd_seq.start(env.agent.sequencer);
      wr_seq = pcie_cfg_wr_seq::type_id::create($sformatf("rmw_wr_%0d", i));
      wr_seq.type1    = 0; wr_seq.num_pkts = 1;
      wr_seq.start(env.agent.sequencer);
    end

    #200ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_cfg_access_test

`endif
