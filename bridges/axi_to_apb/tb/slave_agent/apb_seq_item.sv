`ifndef APB_SLV_SEQ_ITEM_SV
`define APB_SLV_SEQ_ITEM_SV
typedef enum bit {APB_SLV_WRITE, APB_SLV_READ} apb_slv_op_e;
class apb_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_enum(apb_slv_op_e, op, UVM_ALL_ON)
    `uvm_field_int(addr,               UVM_ALL_ON)
    `uvm_field_int(data,               UVM_ALL_ON)
    `uvm_field_int(pslverr,            UVM_ALL_ON)
  `uvm_object_utils_end
  apb_slv_op_e op;
  bit [31:0]   addr;
  bit [31:0]   data;
  bit          pslverr;
  function new(string name = "apb_seq_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("APB op=%s addr=0x%08h data=0x%08h slverr=%0b", op.name(), addr, data, pslverr);
  endfunction
endclass
`endif
