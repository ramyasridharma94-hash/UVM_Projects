`ifndef AXI4_SEQ_ITEM_SV
`define AXI4_SEQ_ITEM_SV
class axi4_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(axi4_seq_item)
    `uvm_field_int(addr,UVM_ALL_ON) `uvm_field_int(len,UVM_ALL_ON)
    `uvm_field_int(id,  UVM_ALL_ON) `uvm_field_int(data,UVM_ALL_ON)
    `uvm_field_int(strb,UVM_ALL_ON) `uvm_field_int(resp,UVM_ALL_ON)
    `uvm_field_int(is_write,UVM_ALL_ON)
  `uvm_object_utils_end
  logic [63:0]  addr;
  logic [7:0]   len, id;
  logic [127:0] data;
  logic [15:0]  strb;
  logic [1:0]   resp;
  logic         is_write;
  function new(string name="axi4_seq_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("%s addr=0x%016h len=%0d id=%0d resp=%02b",
                     is_write?"WR":"RD", addr, len, id, resp);
  endfunction
endclass
`endif
