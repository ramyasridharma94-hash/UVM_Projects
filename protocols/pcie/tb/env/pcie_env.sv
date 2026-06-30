`ifndef PCIE_ENV_SV
`define PCIE_ENV_SV

class pcie_env extends uvm_env;
  `uvm_component_utils(pcie_env)

  import pcie_pkg::*;

  pcie_agent      agent;
  pcie_scoreboard scoreboard;
  pcie_coverage   coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = pcie_agent::type_id::create("agent",      this);
    scoreboard = pcie_scoreboard::type_id::create("scoreboard", this);
    coverage   = pcie_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    // Connect all monitor analysis ports to scoreboard and coverage
    agent.monitor.ap_req.connect      (scoreboard.ap_req);
    agent.monitor.ap_posted.connect   (scoreboard.ap_posted);
    agent.monitor.ap_non_posted.connect(scoreboard.ap_np);
    agent.monitor.ap_completion.connect(scoreboard.ap_cpl);
    agent.monitor.ap_cfg.connect      (scoreboard.ap_cfg);
    agent.monitor.ap_error.connect    (scoreboard.ap_err);

    // Coverage samples from all TLPs (req stream)
    agent.monitor.ap_req.connect(coverage.analysis_export);
  endfunction

endclass : pcie_env

`endif
