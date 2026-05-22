`ifndef AHB_SEQ_ITEM_SV
`define AHB_SEQ_ITEM_SV

typedef enum bit {AHB_WRITE, AHB_READ} ahb_op_e;

class ahb_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(ahb_seq_item)
    `uvm_field_enum(ahb_op_e, op,    UVM_ALL_ON)
    `uvm_field_int (addr,             UVM_ALL_ON)
    `uvm_field_int (size,             UVM_ALL_ON)
    `uvm_field_int (burst,            UVM_ALL_ON)
    `uvm_field_array_int(data,        UVM_ALL_ON)
    `uvm_field_int (hresp,            UVM_ALL_ON)
  `uvm_object_utils_end

  rand ahb_op_e  op;
  rand bit [31:0] addr;
  rand bit [2:0]  size;   // HSIZE: 010=word
  rand bit [2:0]  burst;  // 0=SINGLE,1=INCR,3=INCR4
  rand bit [31:0] data[];
       bit        hresp;

  constraint c_addr_align  { addr[1:0] == 2'b00; }
  constraint c_size_word   { size == 3'b010; }
  constraint c_burst_range { burst inside {3'b000, 3'b001, 3'b011}; }
  constraint c_data_beats  {
    burst == 3'b000 -> data.size() == 1;  // SINGLE
    burst == 3'b001 -> data.size() inside {[1:8]};  // INCR
    burst == 3'b011 -> data.size() == 4;  // INCR4
  }

  function new(string name = "ahb_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("op=%s addr=0x%08h burst=%0d beats=%0d resp=%0b",
                     op.name(), addr, burst, data.size(), hresp);
  endfunction

endclass

`endif
