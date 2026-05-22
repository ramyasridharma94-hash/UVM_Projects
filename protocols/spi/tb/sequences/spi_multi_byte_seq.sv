`ifndef SPI_MULTI_BYTE_SEQ_SV
`define SPI_MULTI_BYTE_SEQ_SV
class spi_multi_byte_seq extends spi_base_seq;
  `uvm_object_utils(spi_multi_byte_seq)
  int unsigned num_txns = 4;
  function new(string name = "spi_multi_byte_seq"); super.new(name); endfunction
  task body();
    spi_seq_item req;
    repeat (num_txns) begin
      req = spi_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { data.size() inside {[2:4]}; op == SPI_WRITE; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass
`endif
