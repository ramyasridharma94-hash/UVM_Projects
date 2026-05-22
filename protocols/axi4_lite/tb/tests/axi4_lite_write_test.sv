`ifndef AXI4_LITE_WRITE_TEST_SV
`define AXI4_LITE_WRITE_TEST_SV
class axi4_lite_write_test extends axi4_lite_base_test;
  `uvm_component_utils(axi4_lite_write_test)
  function new(string name = "axi4_lite_write_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    axi4_lite_write_seq seq;
    phase.raise_objection(this);
    seq = axi4_lite_write_seq::type_id::create("seq");
    seq.num_txns = 8;
    seq.start(env.agent.seqr);
    #100;
    phase.drop_objection(this);
  endtask
endclass
`endif
