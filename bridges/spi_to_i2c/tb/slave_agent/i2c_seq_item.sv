`ifndef I2C_BRIDGE_SEQ_ITEM_SV
`define I2C_BRIDGE_SEQ_ITEM_SV
typedef enum bit {I2C_BR_WRITE, I2C_BR_READ} i2c_br_op_e;
class i2c_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(i2c_seq_item)
    `uvm_field_enum(i2c_br_op_e, op, UVM_ALL_ON)
    `uvm_field_int(slave_addr,        UVM_ALL_ON)
    `uvm_field_int(data,              UVM_ALL_ON)
  `uvm_object_utils_end
  i2c_br_op_e op;
  bit [6:0]   slave_addr;
  bit [7:0]   data;
  function new(string name = "i2c_seq_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("I2C op=%s addr=0x%02h data=0x%02h", op.name(), slave_addr, data);
  endfunction
endclass
`endif
