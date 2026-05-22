`ifndef I2C_SEQ_ITEM_SV
`define I2C_SEQ_ITEM_SV

typedef enum bit {I2C_WRITE, I2C_READ} i2c_op_e;

class i2c_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(i2c_seq_item)
    `uvm_field_enum(i2c_op_e, op,  UVM_ALL_ON)
    `uvm_field_int (slave_addr,     UVM_ALL_ON)
    `uvm_field_int (reg_addr,       UVM_ALL_ON)
    `uvm_field_array_int(data,      UVM_ALL_ON)
    `uvm_field_int (nack,           UVM_ALL_ON)
  `uvm_object_utils_end

  rand i2c_op_e  op;
  rand bit [6:0] slave_addr;
  rand bit [7:0] reg_addr;
  rand bit [7:0] data[];
       bit        nack;

  constraint c_slave_fixed { slave_addr == 7'h50; }
  constraint c_reg_range   { reg_addr < 8; }
  constraint c_data_size   { data.size() inside {[1:4]}; }

  function new(string name = "i2c_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("op=%s saddr=0x%02h raddr=0x%02h bytes=%0d nack=%0b",
                     op.name(), slave_addr, reg_addr, data.size(), nack);
  endfunction

endclass

`endif
