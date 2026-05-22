`ifndef AXI4_SEQ_ITEM_SV
`define AXI4_SEQ_ITEM_SV

typedef enum bit {AXI4_WRITE, AXI4_READ} axi4_op_e;

class axi4_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(axi4_seq_item)
    `uvm_field_enum(axi4_op_e, op,    UVM_ALL_ON)
    `uvm_field_int (addr,              UVM_ALL_ON)
    `uvm_field_int (len,               UVM_ALL_ON)
    `uvm_field_int (size,              UVM_ALL_ON)
    `uvm_field_int (burst,             UVM_ALL_ON)
    `uvm_field_int (id,                UVM_ALL_ON)
    `uvm_field_array_int(data,         UVM_ALL_ON)
    `uvm_field_array_int(strb,         UVM_ALL_ON)
    `uvm_field_int (resp,              UVM_ALL_ON)
  `uvm_object_utils_end

  rand axi4_op_e   op;
  rand bit [31:0]  addr;
  rand bit [7:0]   len;    // AXLEN: burst length - 1
  rand bit [2:0]   size;   // AXSIZE: 2^size bytes per beat
  rand bit [1:0]   burst;  // 00=FIXED,01=INCR,10=WRAP
  rand bit [3:0]   id;
  rand bit [31:0]  data[];
  rand bit [3:0]   strb[];
       bit [1:0]   resp;

  constraint c_addr_align  { addr[1:0] == 2'b00; }
  constraint c_len_range   { len inside {[0:15]}; }
  constraint c_size_word   { size == 3'b010; }       // 4-byte transfers
  constraint c_burst_type  { burst inside {1, 2}; }  // INCR or WRAP
  constraint c_data_size   { data.size() == len + 1;
                              strb.size() == len + 1; }
  constraint c_strb_full   { foreach (strb[i]) strb[i] == 4'hF; }

  function new(string name = "axi4_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("op=%s addr=0x%08h len=%0d id=%0d resp=%0b",
                     op.name(), addr, len, id, resp);
  endfunction

endclass

`endif
