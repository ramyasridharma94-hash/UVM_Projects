`ifndef BRIDGE_SPI_I2C_BASE_SEQ_SV
`define BRIDGE_SPI_I2C_BASE_SEQ_SV
class bridge_base_seq extends uvm_sequence #(spi_seq_item);
  `uvm_object_utils(bridge_base_seq)
  function new(string name = "bridge_base_seq"); super.new(name); endfunction
  task body(); endtask
endclass
`endif
