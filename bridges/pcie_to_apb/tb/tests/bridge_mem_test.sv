`ifndef APB_BRIDGE_MEM_TEST_SV
`define APB_BRIDGE_MEM_TEST_SV
class bridge_mem_test extends bridge_base_test;
  `uvm_component_utils(bridge_mem_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    bridge_mem_rd_seq rd; bridge_mem_wr_seq wr;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== APB Memory-Mapped Access Test ===",UVM_LOW)
    wr = bridge_mem_wr_seq::type_id::create("memwr"); wr.num_pkts=16;
    wr.start(env.pcie_agent.sequencer);
    rd = bridge_mem_rd_seq::type_id::create("memrd"); rd.num_pkts=16;
    rd.start(env.pcie_agent.sequencer);
    #200ns; phase.drop_objection(this);
  endtask
endclass
`endif
