`ifndef BRIDGE_AXI_APB_COVERAGE_SV
`define BRIDGE_AXI_APB_COVERAGE_SV
class bridge_coverage extends uvm_subscriber #(axi_lite_seq_item);
  `uvm_component_utils(bridge_coverage)
  axi_lite_seq_item item;
  covergroup bridge_cg;
    cp_op:   coverpoint item.op   { bins wr={AXIL_WRITE}; bins rd={AXIL_READ}; }
    cp_resp: coverpoint item.resp { bins okay={0}; bins err={2}; }
    cx: cross cp_op, cp_resp;
  endgroup
  function new(string name = "bridge_coverage", uvm_component parent = null);
    super.new(name, parent);
    bridge_cg = new();
  endfunction
  function void write(axi_lite_seq_item t); item = t; bridge_cg.sample(); endfunction
endclass
`endif
