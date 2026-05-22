`ifndef AHB_ENV_SV
`define AHB_ENV_SV
class ahb_env extends uvm_env;
  `uvm_component_utils(ahb_env)
  ahb_agent      agent;
  ahb_scoreboard sb;
  ahb_coverage   cov;
  function new(string name = "ahb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = ahb_agent::type_id::create("agent", this);
    sb    = ahb_scoreboard::type_id::create("sb",    this);
    cov   = ahb_coverage::type_id::create("cov",  this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agent.ap.connect(sb.analysis_export);
    agent.ap.connect(cov.analysis_export);
  endfunction
endclass
`endif
