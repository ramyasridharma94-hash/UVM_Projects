`ifndef I2C_BASE_SEQ_SV
`define I2C_BASE_SEQ_SV
class i2c_base_seq extends uvm_sequence #(i2c_seq_item);
  `uvm_object_utils(i2c_base_seq)
  function new(string name = "i2c_base_seq"); super.new(name); endfunction
  task body(); endtask
endclass
`endif
