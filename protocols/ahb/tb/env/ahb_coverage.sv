`ifndef AHB_COVERAGE_SV
`define AHB_COVERAGE_SV
class ahb_coverage extends uvm_subscriber #(ahb_seq_item);
  `uvm_component_utils(ahb_coverage)
  ahb_seq_item item;
  covergroup ahb_cg;
    cp_op:    coverpoint item.op    { bins wr={AHB_WRITE}; bins rd={AHB_READ}; }
    cp_burst: coverpoint item.burst { bins single={0}; bins incr={1}; bins incr4={3}; }
    cp_size:  coverpoint item.size  { bins byte_={0}; bins hword={1}; bins word={2}; }
    cx_op_burst: cross cp_op, cp_burst;
  endgroup
  function new(string name = "ahb_coverage", uvm_component parent = null);
    super.new(name, parent);
    ahb_cg = new();
  endfunction
  function void write(ahb_seq_item t); item = t; ahb_cg.sample(); endfunction
endclass
`endif
