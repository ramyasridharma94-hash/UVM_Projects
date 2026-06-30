`ifndef AXI4_BRIDGE_MIXED_TEST_SV
`define AXI4_BRIDGE_MIXED_TEST_SV
class bridge_mixed_test extends bridge_base_test;
  `uvm_component_utils(bridge_mixed_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    bridge_mixed_seq ms;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== AXI4 Bridge Mixed Test ===",UVM_LOW)
    ms=bridge_mixed_seq::type_id::create("ms"); ms.num_pkts=40;
    ms.start(env.pcie_agent.sequencer);
    #300ns; phase.drop_objection(this);
  endtask
endclass
`endif
