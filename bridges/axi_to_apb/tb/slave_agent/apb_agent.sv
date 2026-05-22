`ifndef APB_SLV_AGENT_SV
`define APB_SLV_AGENT_SV
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)
  apb_monitor mon;
  uvm_analysis_port #(apb_seq_item) ap;
  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    set_is_active(UVM_PASSIVE);
    mon = apb_monitor::type_id::create("mon", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    mon.ap.connect(ap);
  endfunction
endclass
`endif
