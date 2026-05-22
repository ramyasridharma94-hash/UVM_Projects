`ifndef AXI4_LITE_COVERAGE_SV
`define AXI4_LITE_COVERAGE_SV
class axi4_lite_coverage extends uvm_subscriber #(axi4_lite_seq_item);
  `uvm_component_utils(axi4_lite_coverage)
  axi4_lite_seq_item item;
  covergroup axi4l_cg;
    cp_op:   coverpoint item.op   { bins wr={AXI4L_WRITE}; bins rd={AXI4L_READ}; }
    cp_resp: coverpoint item.resp { bins okay={2'b00}; bins err={2'b10}; }
    cx_op_resp: cross cp_op, cp_resp;
  endgroup
  function new(string name = "axi4_lite_coverage", uvm_component parent = null);
    super.new(name, parent);
    axi4l_cg = new();
  endfunction
  function void write(axi4_lite_seq_item t); item = t; axi4l_cg.sample(); endfunction
endclass
`endif
