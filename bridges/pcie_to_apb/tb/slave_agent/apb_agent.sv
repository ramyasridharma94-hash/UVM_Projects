`ifndef APB_AGENT_SV
`define APB_AGENT_SV
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)
  apb_monitor monitor;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = apb_monitor::type_id::create("monitor", this);
  endfunction
endclass
`endif
