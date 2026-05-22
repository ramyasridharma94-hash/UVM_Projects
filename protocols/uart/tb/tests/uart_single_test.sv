`ifndef UART_SINGLE_TEST_SV
`define UART_SINGLE_TEST_SV
class uart_single_test extends uart_base_test;
  `uvm_component_utils(uart_single_test)
  function new(string name = "uart_single_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    uart_single_byte_seq seq;
    phase.raise_objection(this);
    seq = uart_single_byte_seq::type_id::create("seq");
    seq.num_txns = 4;
    seq.start(env.agent.seqr);
    #50000; // Wait for UART transmissions at 115200 baud
    phase.drop_objection(this);
  endtask
endclass
`endif
