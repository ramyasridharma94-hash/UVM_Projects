`ifndef DDR5_MRS_TEST_SV
`define DDR5_MRS_TEST_SV
class ddr5_mrs_test extends ddr5_base_test;
  `uvm_component_utils(ddr5_mrs_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    ddr5_mrs_seq ms;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== DDR5 Mode Register Test (MR0-MR37) ===",UVM_LOW)
    ms=ddr5_mrs_seq::type_id::create("mrs_prog"); ms.start(env.agent.sequencer);
    #300ns; phase.drop_objection(this);
  endtask
endclass
`endif
