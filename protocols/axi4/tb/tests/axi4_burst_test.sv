`ifndef AXI4_BURST_TEST_SV
`define AXI4_BURST_TEST_SV

class axi4_burst_test extends axi4_base_test;
  `uvm_component_utils(axi4_burst_test)

  function new(string name = "axi4_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi4_burst_seq seq;
    phase.raise_objection(this);
    seq = axi4_burst_seq::type_id::create("seq");
    seq.num_txns = 4;
    seq.start(env.agent.seqr);
    #200;
    phase.drop_objection(this);
  endtask

endclass

`endif
