`ifndef AHB_SINGLE_TEST_SV
`define AHB_SINGLE_TEST_SV
class ahb_single_test extends ahb_base_test;
  `uvm_component_utils(ahb_single_test)
  function new(string name = "ahb_single_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    ahb_single_seq seq;
    phase.raise_objection(this);
    seq = ahb_single_seq::type_id::create("seq");
    seq.num_txns = 16;
    seq.start(env.agent.seqr);
    #100;
    phase.drop_objection(this);
  endtask
endclass
`endif
