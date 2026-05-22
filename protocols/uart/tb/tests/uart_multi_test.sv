`ifndef UART_MULTI_TEST_SV
`define UART_MULTI_TEST_SV
class uart_multi_test extends uart_base_test;
  `uvm_component_utils(uart_multi_test)
  function new(string name = "uart_multi_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    uart_multi_byte_seq seq;
    phase.raise_objection(this);
    seq = uart_multi_byte_seq::type_id::create("seq");
    seq.num_txns = 16;
    seq.start(env.agent.seqr);
    #500000;
    phase.drop_objection(this);
  endtask
endclass
`endif
