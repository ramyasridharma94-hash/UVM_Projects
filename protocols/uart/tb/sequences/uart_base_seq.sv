`ifndef UART_BASE_SEQ_SV
`define UART_BASE_SEQ_SV
class uart_base_seq extends uvm_sequence #(uart_seq_item);
  `uvm_object_utils(uart_base_seq)
  function new(string name = "uart_base_seq"); super.new(name); endfunction
  task body(); endtask
endclass
`endif
