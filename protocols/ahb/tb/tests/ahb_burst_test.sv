`ifndef AHB_BURST_TEST_SV
`define AHB_BURST_TEST_SV
class ahb_burst_test extends ahb_base_test;
  `uvm_component_utils(ahb_burst_test)
  function new(string name = "ahb_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    ahb_burst_seq seq;
    phase.raise_objection(this);
    seq = ahb_burst_seq::type_id::create("seq");
    seq.num_txns = 4;
    seq.start(env.agent.seqr);
    #100;
    phase.drop_objection(this);
  endtask
endclass
`endif
