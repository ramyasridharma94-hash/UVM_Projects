`ifndef UART_COVERAGE_SV
`define UART_COVERAGE_SV
class uart_coverage extends uvm_subscriber #(uart_seq_item);
  `uvm_component_utils(uart_coverage)
  uart_seq_item item;
  covergroup uart_cg;
    cp_data: coverpoint item.data {
      bins zeros     = {8'h00};
      bins ff        = {8'hFF};
      bins printable = {[8'h20:8'h7E]};
      bins other[]   = default;
    }
  endgroup
  function new(string name = "uart_coverage", uvm_component parent = null);
    super.new(name, parent);
    uart_cg = new();
  endfunction
  function void write(uart_seq_item t); item = t; uart_cg.sample(); endfunction
endclass
`endif
