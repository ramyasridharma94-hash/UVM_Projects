`ifndef SPI_BASE_SEQ_SV
`define SPI_BASE_SEQ_SV
class spi_base_seq extends uvm_sequence #(spi_seq_item);
  `uvm_object_utils(spi_base_seq)
  function new(string name = "spi_base_seq"); super.new(name); endfunction
  task body(); endtask
endclass
`endif
