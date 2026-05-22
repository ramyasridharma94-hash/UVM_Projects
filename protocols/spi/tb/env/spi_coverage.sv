`ifndef SPI_COVERAGE_SV
`define SPI_COVERAGE_SV
class spi_coverage extends uvm_subscriber #(spi_seq_item);
  `uvm_component_utils(spi_coverage)
  spi_seq_item item;
  covergroup spi_cg;
    cp_op:   coverpoint item.op   { bins wr={SPI_WRITE}; bins rd={SPI_READ}; }
    cp_addr: coverpoint item.addr { bins regs[] = {[0:7]}; }
    cp_len:  coverpoint item.data.size() { bins one={1}; bins multi[]={[2:4]}; }
    cx_op_len: cross cp_op, cp_len;
  endgroup
  function new(string name = "spi_coverage", uvm_component parent = null);
    super.new(name, parent);
    spi_cg = new();
  endfunction
  function void write(spi_seq_item t); item = t; spi_cg.sample(); endfunction
endclass
`endif
