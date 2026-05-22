`ifndef AXI4_READ_TEST_SV
`define AXI4_READ_TEST_SV

class axi4_read_test extends axi4_base_test;
  `uvm_component_utils(axi4_read_test)

  function new(string name = "axi4_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_write_seq wr_seq;
    axi4_read_seq  rd_seq;
    phase.raise_objection(this);
    // First write known data
    wr_seq = axi4_write_seq::type_id::create("wr_seq");
    wr_seq.num_txns = 8;
    wr_seq.start(env.agent.seqr);
    // Then read it back — scoreboard checks correctness
    rd_seq = axi4_read_seq::type_id::create("rd_seq");
    rd_seq.num_txns = 8;
    rd_seq.start(env.agent.seqr);
    #100;
    phase.drop_objection(this);
  endtask

endclass

`endif
