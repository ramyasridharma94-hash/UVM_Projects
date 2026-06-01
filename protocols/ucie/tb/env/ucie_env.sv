`ifndef UCIE_ENV_SV
`define UCIE_ENV_SV

class ucie_env extends uvm_env;
  `uvm_component_utils(ucie_env)

  ucie_agent      agent;
  ucie_scoreboard sb;
  ucie_coverage   cov;

  function new(string name = "ucie_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = ucie_agent::type_id::create("agent", this);
    sb    = ucie_scoreboard::type_id::create("sb",  this);
    cov   = ucie_coverage::type_id::create("cov",  this);
  endfunction

  function void connect_phase(uvm_phase phase);
    // Scoreboard: TX side for expected, RX side for actual
    agent.tx_ap.connect(sb.tx_export);
    agent.rx_ap.connect(sb.rx_export);
    // Coverage samples received flits
    agent.rx_ap.connect(cov.analysis_export);
  endfunction

endclass

`endif
