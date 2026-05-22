`ifndef SPI_BRIDGE_SEQ_ITEM_SV
`define SPI_BRIDGE_SEQ_ITEM_SV
typedef enum bit {SPI_BR_WRITE, SPI_BR_READ} spi_br_op_e;
class spi_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(spi_seq_item)
    `uvm_field_enum(spi_br_op_e, op, UVM_ALL_ON)
    `uvm_field_int(i2c_addr,          UVM_ALL_ON)
    `uvm_field_int(data,              UVM_ALL_ON)
  `uvm_object_utils_end
  rand spi_br_op_e  op;
  rand bit [6:0]    i2c_addr;   // I2C slave address to target
  rand bit [7:0]    data;       // data byte to send/receive
  constraint c_addr { i2c_addr == 7'h50; } // fixed slave address
  function new(string name = "spi_seq_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("op=%s i2c_addr=0x%02h data=0x%02h", op.name(), i2c_addr, data);
  endfunction
endclass
`endif
