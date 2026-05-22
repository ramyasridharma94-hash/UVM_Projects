`ifndef UART_ENV_SV
`define UART_ENV_SV
class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)
  uart_agent      agent;
  uart_scoreboard sb;
  uart_coverage   cov;
  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = uart_agent::type_id::create("agent", this);
    sb    = uart_scoreboard::type_id::create("sb",  this);
    cov   = uart_coverage::type_id::create("cov",  this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agent.ap.connect(sb.analysis_export);
    agent.ap.connect(cov.analysis_export);
  endfunction
endclass
`endif
