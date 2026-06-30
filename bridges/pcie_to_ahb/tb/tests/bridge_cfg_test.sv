`ifndef AHB_BRIDGE_CFG_TEST_SV
`define AHB_BRIDGE_CFG_TEST_SV
class bridge_cfg_test extends bridge_base_test;
  `uvm_component_utils(bridge_cfg_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    bridge_cfg_seq cs;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== AHB Bridge Config Test ===",UVM_LOW)
    cs=bridge_cfg_seq::type_id::create("cs"); cs.num_pkts=10;
    cs.start(env.pcie_agent.sequencer);
    #200ns; phase.drop_objection(this);
  endtask
endclass
`endif
