`ifndef APB_ENV_SV
`define APB_ENV_SV
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)
  apb_agent      agent;
  apb_scoreboard sb;
  apb_coverage   cov;
  function new(string name = "apb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = apb_agent::type_id::create("agent", this);
    sb    = apb_scoreboard::type_id::create("sb",  this);
    cov   = apb_coverage::type_id::create("cov",  this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agent.ap.connect(sb.analysis_export);
    agent.ap.connect(cov.analysis_export);
  endfunction
endclass
`endif
