`ifndef AXI4_AGENT_SV
`define AXI4_AGENT_SV
class axi4_agent extends uvm_agent;
  `uvm_component_utils(axi4_agent)
  axi4_monitor monitor;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); monitor=axi4_monitor::type_id::create("monitor",this);
  endfunction
endclass
`endif
