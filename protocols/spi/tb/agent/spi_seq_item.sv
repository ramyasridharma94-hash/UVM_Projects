`ifndef SPI_SEQ_ITEM_SV
`define SPI_SEQ_ITEM_SV

typedef enum bit {SPI_WRITE, SPI_READ} spi_op_e;

class spi_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(spi_seq_item)
    `uvm_field_enum(spi_op_e, op, UVM_ALL_ON)
    `uvm_field_int (addr,          UVM_ALL_ON)
    `uvm_field_array_int(data,     UVM_ALL_ON)
  `uvm_object_utils_end

  rand spi_op_e  op;
  rand bit [6:0] addr;   // 7-bit register address
  rand bit [7:0] data[]; // data bytes

  constraint c_addr_range { addr < 8; }
  constraint c_data_size  { data.size() inside {[1:4]}; }

  function new(string name = "spi_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("op=%s addr=0x%02h bytes=%0d", op.name(), addr, data.size());
  endfunction

endclass

`endif
