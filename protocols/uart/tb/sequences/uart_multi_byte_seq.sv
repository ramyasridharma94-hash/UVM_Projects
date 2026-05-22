`ifndef UART_MULTI_BYTE_SEQ_SV
`define UART_MULTI_BYTE_SEQ_SV
class uart_multi_byte_seq extends uart_base_seq;
  `uvm_object_utils(uart_multi_byte_seq)
  int unsigned num_txns = 16;
  function new(string name = "uart_multi_byte_seq"); super.new(name); endfunction
  task body();
    uart_seq_item req;
    // Send "Hello World!\n" bytes
    byte hello[] = "Hello World!\n";
    foreach (hello[i]) begin
      req = uart_seq_item::type_id::create("req");
      start_item(req);
      req.data = hello[i];
      finish_item(req);
    end
    // Then random bytes
    repeat (num_txns) begin
      req = uart_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize()) `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass
`endif
