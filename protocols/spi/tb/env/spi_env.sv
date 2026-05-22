`ifndef SPI_ENV_SV
`define SPI_ENV_SV
class spi_env extends uvm_env;
  `uvm_component_utils(spi_env)
  spi_agent      agent;
  spi_scoreboard sb;
  spi_coverage   cov;
  function new(string name = "spi_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = spi_agent::type_id::create("agent", this);
    sb    = spi_scoreboard::type_id::create("sb",  this);
    cov   = spi_coverage::type_id::create("cov",  this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agent.ap.connect(sb.analysis_export);
    agent.ap.connect(cov.analysis_export);
  endfunction
endclass
`endif
