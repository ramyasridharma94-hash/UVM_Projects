`ifndef APB_BRIDGE_ERROR_TEST_SV
`define APB_BRIDGE_ERROR_TEST_SV
class bridge_error_test extends bridge_base_test;
  `uvm_component_utils(bridge_error_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db #(bit)::set(this,"env.scoreboard","expected_errors",1);
  endfunction
  task run_phase(uvm_phase phase);
    bridge_error_seq es;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== APB Bridge Error Test (pslverr → CPL_CA) ===",UVM_LOW)
    es = bridge_error_seq::type_id::create("errs");
    es.start(env.pcie_agent.sequencer);
    #200ns; phase.drop_objection(this);
  endtask
endclass
`endif
