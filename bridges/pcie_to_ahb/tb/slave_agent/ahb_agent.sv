`ifndef AHB_AGENT_SV
`define AHB_AGENT_SV
class ahb_agent extends uvm_agent;
  `uvm_component_utils(ahb_agent)
  ahb_monitor monitor;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); monitor = ahb_monitor::type_id::create("monitor",this);
  endfunction
endclass
`endif
