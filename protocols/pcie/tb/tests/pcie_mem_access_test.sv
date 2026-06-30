`ifndef PCIE_MEM_ACCESS_TEST_SV
`define PCIE_MEM_ACCESS_TEST_SV

// Memory access test — exercises MRd32/64 and MWr32/64 with various lengths and TCs
class pcie_mem_access_test extends pcie_base_test;
  `uvm_component_utils(pcie_mem_access_test)

  import pcie_pkg::*;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_mem_wr_seq          wr_seq;
    pcie_mem_rd_seq          rd_seq;
    pcie_mem_wr_directed_seq wr_dir;
    pcie_mem_rd32_directed_seq rd_dir;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== Memory Access Test ===", UVM_LOW)

    // Directed 64-bit write to known address
    wr_dir = pcie_mem_wr_directed_seq::type_id::create("wr_dir");
    wr_dir.start(env.agent.sequencer);

    // Directed 32-bit read from same area
    rd_dir = pcie_mem_rd32_directed_seq::type_id::create("rd_dir");
    rd_dir.start(env.agent.sequencer);

    // Random 32-bit write burst
    wr_seq = pcie_mem_wr_seq::type_id::create("wr32");
    wr_seq.use_64bit  = 0;
    wr_seq.poison_ep  = 0;
    wr_seq.num_pkts   = 20;
    wr_seq.start(env.agent.sequencer);

    // Random 64-bit write burst
    wr_seq = pcie_mem_wr_seq::type_id::create("wr64");
    wr_seq.use_64bit  = 1;
    wr_seq.num_pkts   = 20;
    wr_seq.start(env.agent.sequencer);

    // Random 32-bit read burst
    rd_seq = pcie_mem_rd_seq::type_id::create("rd32");
    rd_seq.use_64bit  = 0;
    rd_seq.use_lock   = 0;
    rd_seq.num_pkts   = 20;
    rd_seq.start(env.agent.sequencer);

    // Random 64-bit read burst
    rd_seq = pcie_mem_rd_seq::type_id::create("rd64");
    rd_seq.use_64bit  = 1;
    rd_seq.num_pkts   = 20;
    rd_seq.start(env.agent.sequencer);

    // Locked read (MRdLk)
    rd_seq = pcie_mem_rd_seq::type_id::create("rdlk");
    rd_seq.use_lock  = 1;
    rd_seq.num_pkts  = 4;
    rd_seq.start(env.agent.sequencer);

    // Poisoned write (EP=1)
    wr_seq = pcie_mem_wr_seq::type_id::create("wr_poison");
    wr_seq.poison_ep = 1;
    wr_seq.num_pkts  = 4;
    wr_seq.start(env.agent.sequencer);

    #200ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_mem_access_test

`endif
