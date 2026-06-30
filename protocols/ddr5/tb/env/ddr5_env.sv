`ifndef DDR5_ENV_SV
`define DDR5_ENV_SV
class ddr5_env extends uvm_env;
  `uvm_component_utils(ddr5_env)
  import ddr5_pkg::*;
  ddr5_agent      agent;
  ddr5_scoreboard scoreboard;
  ddr5_coverage   coverage;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = ddr5_agent::type_id::create("agent",     this);
    scoreboard = ddr5_scoreboard::type_id::create("scoreboard",this);
    coverage   = ddr5_coverage::type_id::create("coverage",  this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agent.monitor.ap_cmd.connect(scoreboard.ap_cmd);
    agent.monitor.ap_rd.connect (scoreboard.ap_rd);
    agent.monitor.ap_wr.connect (scoreboard.ap_wr);
    agent.monitor.ap_ref.connect(scoreboard.ap_ref);
    agent.monitor.ap_err.connect(scoreboard.ap_err);
    agent.monitor.ap_cmd.connect(coverage.analysis_export);
  endfunction
endclass
`endif
