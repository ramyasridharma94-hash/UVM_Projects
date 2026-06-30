`ifndef DDR5_PM_TEST_SV
`define DDR5_PM_TEST_SV
class ddr5_pm_test extends ddr5_base_test;
  `uvm_component_utils(ddr5_pm_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    ddr5_pm_seq ps;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== DDR5 Power Management Test (PD/SREF) ===",UVM_LOW)
    ps=ddr5_pm_seq::type_id::create("pm"); ps.start(env.agent.sequencer);
    #500ns; phase.drop_objection(this);
  endtask
endclass
`endif
