`ifndef APB_SEQ_ITEM_SV
`define APB_SEQ_ITEM_SV

typedef enum bit {APB_WRITE, APB_READ} apb_op_e;

class apb_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_enum(apb_op_e, op,   UVM_ALL_ON)
    `uvm_field_int (addr,            UVM_ALL_ON)
    `uvm_field_int (data,            UVM_ALL_ON)
    `uvm_field_int (pslverr,         UVM_ALL_ON)
  `uvm_object_utils_end

  rand apb_op_e  op;
  rand bit [31:0] addr;
  rand bit [31:0] data;
       bit        pslverr;

  constraint c_addr_align { addr[1:0] == 2'b00; }
  constraint c_addr_range { (addr >> 2) < 8; } // valid register range

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("op=%s addr=0x%08h data=0x%08h slverr=%0b",
                     op.name(), addr, data, pslverr);
  endfunction

endclass

`endif
