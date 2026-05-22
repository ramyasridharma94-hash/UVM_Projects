`ifndef AHB_MST_SEQ_ITEM_SV
`define AHB_MST_SEQ_ITEM_SV
typedef enum bit {AHB_MST_WRITE, AHB_MST_READ} ahb_mst_op_e;
class ahb_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(ahb_seq_item)
    `uvm_field_enum(ahb_mst_op_e, op, UVM_ALL_ON)
    `uvm_field_int(addr,               UVM_ALL_ON)
    `uvm_field_int(data,               UVM_ALL_ON)
    `uvm_field_int(hresp,              UVM_ALL_ON)
  `uvm_object_utils_end
  rand ahb_mst_op_e op;
  rand bit [31:0]   addr;
  rand bit [31:0]   data;
       bit          hresp;
  constraint c_align { addr[1:0] == 0; }
  function new(string name = "ahb_seq_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("AHB op=%s addr=0x%08h data=0x%08h hresp=%0b", op.name(), addr, data, hresp);
  endfunction
endclass
`endif
