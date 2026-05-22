`ifndef BRIDGE_AXI_AHB_ENV_SV
`define BRIDGE_AXI_AHB_ENV_SV
class bridge_env extends uvm_env;
  `uvm_component_utils(bridge_env)
  axi_lite_agent   master_agent;
  ahb_agent        slave_agent;
  bridge_scoreboard sb;
  bridge_coverage   cov;
  function new(string name = "bridge_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    master_agent = axi_lite_agent::type_id::create("master_agent", this);
    slave_agent  = ahb_agent::type_id::create("slave_agent",  this);
    sb           = bridge_scoreboard::type_id::create("sb",  this);
    cov          = bridge_coverage::type_id::create("cov",   this);
  endfunction
  function void connect_phase(uvm_phase phase);
    master_agent.ap.connect(sb.master_imp);
    slave_agent.ap.connect(sb.slave_imp);
    master_agent.ap.connect(cov.analysis_export);
  endfunction
endclass
`endif
