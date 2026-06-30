`ifndef APB_BRIDGE_ENV_SV
`define APB_BRIDGE_ENV_SV
class bridge_env extends uvm_env;
  `uvm_component_utils(bridge_env)
  pcie_tlp_agent  pcie_agent;
  apb_agent       apb_agt;
  bridge_scoreboard scoreboard;
  bridge_coverage   coverage;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    pcie_agent  = pcie_tlp_agent::type_id::create("pcie_agent", this);
    apb_agt     = apb_agent::type_id::create("apb_agt",    this);
    scoreboard  = bridge_scoreboard::type_id::create("scoreboard", this);
    coverage    = bridge_coverage::type_id::create("coverage",   this);
  endfunction
  function void connect_phase(uvm_phase phase);
    pcie_agent.monitor.ap_req.connect(scoreboard.ap_req);
    pcie_agent.monitor.ap_cpl.connect(scoreboard.ap_cpl);
    apb_agt.monitor.ap_apb.connect(scoreboard.ap_apb);
    pcie_agent.monitor.ap_req.connect(coverage.analysis_export);
  endfunction
endclass
`endif
