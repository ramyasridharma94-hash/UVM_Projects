`ifndef UART_BASE_TEST_SV
`define UART_BASE_TEST_SV
class uart_base_test extends uvm_test;
  `uvm_component_utils(uart_base_test)
  uart_env env;
  function new(string name = "uart_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #100;
    phase.drop_objection(this);
  endtask
endclass
`endif
