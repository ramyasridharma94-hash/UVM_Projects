`ifndef APB_READ_TEST_SV
`define APB_READ_TEST_SV
class apb_read_test extends apb_base_test;
  `uvm_component_utils(apb_read_test)
  function new(string name = "apb_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    apb_write_seq wr;
    apb_read_seq  rd;
    phase.raise_objection(this);
    wr = apb_write_seq::type_id::create("wr");
    wr.num_txns = 8;
    wr.start(env.agent.seqr);
    rd = apb_read_seq::type_id::create("rd");
    rd.num_txns = 8;
    rd.start(env.agent.seqr);
    #100;
    phase.drop_objection(this);
  endtask
endclass
`endif
