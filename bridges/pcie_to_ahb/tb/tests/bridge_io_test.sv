`ifndef AHB_BRIDGE_IO_TEST_SV
`define AHB_BRIDGE_IO_TEST_SV
class bridge_io_test extends bridge_base_test;
  `uvm_component_utils(bridge_io_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    bridge_io_seq ios;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== AHB Bridge I/O Test ===",UVM_LOW)
    ios=bridge_io_seq::type_id::create("ios"); ios.num_pkts=10;
    ios.start(env.pcie_agent.sequencer);
    #200ns; phase.drop_objection(this);
  endtask
endclass
`endif
