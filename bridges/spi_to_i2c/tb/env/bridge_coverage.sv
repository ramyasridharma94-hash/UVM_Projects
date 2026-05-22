`ifndef BRIDGE_SPI_I2C_COVERAGE_SV
`define BRIDGE_SPI_I2C_COVERAGE_SV
class bridge_coverage extends uvm_subscriber #(spi_seq_item);
  `uvm_component_utils(bridge_coverage)
  spi_seq_item item;
  covergroup bridge_cg;
    cp_op: coverpoint item.op { bins wr={SPI_BR_WRITE}; bins rd={SPI_BR_READ}; }
    cp_addr: coverpoint item.i2c_addr { bins addr50={7'h50}; }
  endgroup
  function new(string name = "bridge_coverage", uvm_component parent = null);
    super.new(name, parent);
    bridge_cg = new();
  endfunction
  function void write(spi_seq_item t); item = t; bridge_cg.sample(); endfunction
endclass
`endif
