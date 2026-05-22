`ifndef UART_SEQ_ITEM_SV
`define UART_SEQ_ITEM_SV

class uart_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(uart_seq_item)
    `uvm_field_int(data,      UVM_ALL_ON)
    `uvm_field_int(baud_rate, UVM_ALL_ON)
  `uvm_object_utils_end

  rand bit [7:0] data;
  int            baud_rate = 115_200;

  function new(string name = "uart_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("data=0x%02h ('%s') baud=%0d", data, string'(data), baud_rate);
  endfunction

endclass

`endif
