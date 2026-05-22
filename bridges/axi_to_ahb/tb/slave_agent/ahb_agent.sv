`ifndef AHB_SLV_AGENT_SV
`define AHB_SLV_AGENT_SV
class ahb_agent extends uvm_agent;
  `uvm_component_utils(ahb_agent)
  ahb_monitor mon;
  uvm_analysis_port #(ahb_seq_item) ap;
  function new(string name = "ahb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    set_is_active(UVM_PASSIVE);
    mon = ahb_monitor::type_id::create("mon", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    mon.ap.connect(ap);
  endfunction
endclass
`endif
