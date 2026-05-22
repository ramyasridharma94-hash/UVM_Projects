`ifndef AXI4_LITE_ENV_SV
`define AXI4_LITE_ENV_SV
class axi4_lite_env extends uvm_env;
  `uvm_component_utils(axi4_lite_env)
  axi4_lite_agent      agent;
  axi4_lite_scoreboard sb;
  axi4_lite_coverage   cov;
  function new(string name = "axi4_lite_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = axi4_lite_agent::type_id::create("agent", this);
    sb    = axi4_lite_scoreboard::type_id::create("sb",  this);
    cov   = axi4_lite_coverage::type_id::create("cov",  this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agent.ap.connect(sb.analysis_export);
    agent.ap.connect(cov.analysis_export);
  endfunction
endclass
`endif
