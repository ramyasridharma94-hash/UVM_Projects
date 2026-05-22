`ifndef UART_SINGLE_BYTE_SEQ_SV
`define UART_SINGLE_BYTE_SEQ_SV
class uart_single_byte_seq extends uart_base_seq;
  `uvm_object_utils(uart_single_byte_seq)
  int unsigned num_txns = 4;
  function new(string name = "uart_single_byte_seq"); super.new(name); endfunction
  task body();
    uart_seq_item req;
    repeat (num_txns) begin
      req = uart_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize()) `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
      `uvm_info("SEQ", $sformatf("Sending: %s", req.convert2string()), UVM_MEDIUM)
    end
  endtask
endclass
`endif
