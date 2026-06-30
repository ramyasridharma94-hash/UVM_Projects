`ifndef AXI4_BRIDGE_READ_TEST_SV
`define AXI4_BRIDGE_READ_TEST_SV
class bridge_read_test extends bridge_base_test;
  `uvm_component_utils(bridge_read_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    bridge_mrd_seq rs;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== AXI4 Bridge Read Test ===",UVM_LOW)
    rs=bridge_mrd_seq::type_id::create("rs32"); rs.num_pkts=20; rs.use_64bit=0;
    rs.start(env.pcie_agent.sequencer);
    rs=bridge_mrd_seq::type_id::create("rs64"); rs.num_pkts=20; rs.use_64bit=1;
    rs.start(env.pcie_agent.sequencer);
    #300ns; phase.drop_objection(this);
  endtask
endclass
`endif
