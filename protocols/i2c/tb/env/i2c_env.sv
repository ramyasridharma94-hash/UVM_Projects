`ifndef I2C_ENV_SV
`define I2C_ENV_SV
class i2c_env extends uvm_env;
  `uvm_component_utils(i2c_env)
  i2c_agent      agent;
  i2c_scoreboard sb;
  i2c_coverage   cov;
  function new(string name = "i2c_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = i2c_agent::type_id::create("agent", this);
    sb    = i2c_scoreboard::type_id::create("sb",  this);
    cov   = i2c_coverage::type_id::create("cov",  this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agent.ap.connect(sb.analysis_export);
    agent.ap.connect(cov.analysis_export);
  endfunction
endclass
`endif
