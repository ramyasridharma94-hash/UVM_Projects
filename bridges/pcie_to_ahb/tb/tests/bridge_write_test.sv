`ifndef AHB_BRIDGE_WRITE_TEST_SV
`define AHB_BRIDGE_WRITE_TEST_SV
class bridge_write_test extends bridge_base_test;
  `uvm_component_utils(bridge_write_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    bridge_write_seq ws;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== AHB Bridge Write Test ===",UVM_LOW)
    ws=bridge_write_seq::type_id::create("ws"); ws.num_pkts=20; ws.use_64bit=0;
    ws.start(env.pcie_agent.sequencer);
    ws=bridge_write_seq::type_id::create("ws64"); ws.num_pkts=10; ws.use_64bit=1;
    ws.start(env.pcie_agent.sequencer);
    #200ns; phase.drop_objection(this);
  endtask
endclass
`endif
