`ifndef AXI4_LITE_READ_TEST_SV
`define AXI4_LITE_READ_TEST_SV
class axi4_lite_read_test extends axi4_lite_base_test;
  `uvm_component_utils(axi4_lite_read_test)
  function new(string name = "axi4_lite_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    axi4_lite_write_seq wr;
    axi4_lite_read_seq  rd;
    phase.raise_objection(this);
    wr = axi4_lite_write_seq::type_id::create("wr");
    wr.num_txns = 8;
    wr.start(env.agent.seqr);
    rd = axi4_lite_read_seq::type_id::create("rd");
    rd.num_txns = 8;
    rd.start(env.agent.seqr);
    #100;
    phase.drop_objection(this);
  endtask
endclass
`endif
