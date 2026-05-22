`ifndef AXI4_LITE_SEQ_ITEM_SV
`define AXI4_LITE_SEQ_ITEM_SV

typedef enum bit {AXI4L_WRITE, AXI4L_READ} axi4l_op_e;

class axi4_lite_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(axi4_lite_seq_item)
    `uvm_field_enum(axi4l_op_e, op,   UVM_ALL_ON)
    `uvm_field_int (addr,              UVM_ALL_ON)
    `uvm_field_int (data,              UVM_ALL_ON)
    `uvm_field_int (strb,              UVM_ALL_ON)
    `uvm_field_int (resp,              UVM_ALL_ON)
  `uvm_object_utils_end

  rand axi4l_op_e  op;
  rand bit [31:0]  addr;
  rand bit [31:0]  data;
  rand bit [3:0]   strb;
       bit [1:0]   resp;

  constraint c_addr_align { addr[1:0] == 2'b00; }
  constraint c_strb_full  { strb == 4'hF; }

  function new(string name = "axi4_lite_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("op=%s addr=0x%08h data=0x%08h resp=%0b",
                     op.name(), addr, data, resp);
  endfunction

endclass

`endif
