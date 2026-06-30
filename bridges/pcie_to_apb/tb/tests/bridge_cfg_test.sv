`ifndef APB_BRIDGE_CFG_TEST_SV
`define APB_BRIDGE_CFG_TEST_SV
class bridge_cfg_test extends bridge_base_test;
  `uvm_component_utils(bridge_cfg_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    bridge_cfg_rd_seq rd; bridge_cfg_wr_seq wr;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== APB Config Space Test ===",UVM_LOW)
    rd = bridge_cfg_rd_seq::type_id::create("cfgrd"); rd.num_pkts=8;
    rd.start(env.pcie_agent.sequencer);
    wr = bridge_cfg_wr_seq::type_id::create("cfgwr"); wr.num_pkts=8;
    wr.start(env.pcie_agent.sequencer);
    #200ns; phase.drop_objection(this);
  endtask
endclass
`endif
