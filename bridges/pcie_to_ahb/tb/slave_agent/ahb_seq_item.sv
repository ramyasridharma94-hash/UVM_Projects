`ifndef AHB_SEQ_ITEM_SV
`define AHB_SEQ_ITEM_SV
class ahb_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(ahb_seq_item)
    `uvm_field_int(addr,  UVM_ALL_ON) `uvm_field_int(data,  UVM_ALL_ON)
    `uvm_field_int(size,  UVM_ALL_ON) `uvm_field_int(burst, UVM_ALL_ON)
    `uvm_field_int(trans, UVM_ALL_ON) `uvm_field_int(resp,  UVM_ALL_ON)
    `uvm_field_int(write, UVM_ALL_ON)
  `uvm_object_utils_end
  logic [31:0] addr, data; logic [2:0] size, burst; logic [1:0] trans, resp; logic write;
  function new(string name="ahb_seq_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("%s addr=0x%08h data=0x%08h burst=%03b resp=%02b",
                     write?"WR":"RD", addr, data, burst, resp);
  endfunction
endclass
`endif
