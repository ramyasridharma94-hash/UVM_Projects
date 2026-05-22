`ifndef APB_WRITE_TEST_SV
`define APB_WRITE_TEST_SV
class apb_write_test extends apb_base_test;
  `uvm_component_utils(apb_write_test)
  function new(string name = "apb_write_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    apb_write_seq seq;
    phase.raise_objection(this);
    seq = apb_write_seq::type_id::create("seq");
    seq.num_txns = 8;
    seq.start(env.agent.seqr);
    #100;
    phase.drop_objection(this);
  endtask
endclass
`endif
