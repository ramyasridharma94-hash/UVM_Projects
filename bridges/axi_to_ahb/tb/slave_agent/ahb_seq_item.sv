`ifndef AHB_SLV_SEQ_ITEM_SV
`define AHB_SLV_SEQ_ITEM_SV
typedef enum bit {AHB_SLV_WRITE, AHB_SLV_READ} ahb_slv_op_e;
class ahb_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(ahb_seq_item)
    `uvm_field_enum(ahb_slv_op_e, op, UVM_ALL_ON)
    `uvm_field_int(addr,               UVM_ALL_ON)
    `uvm_field_int(data,               UVM_ALL_ON)
    `uvm_field_int(hresp,              UVM_ALL_ON)
  `uvm_object_utils_end
  ahb_slv_op_e op;
  bit [31:0]   addr;
  bit [31:0]   data;
  bit          hresp;
  function new(string name = "ahb_seq_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("AHB op=%s addr=0x%08h data=0x%08h hresp=%0b", op.name(), addr, data, hresp);
  endfunction
endclass
`endif
