`ifndef BRIDGE_AHB_APB_COVERAGE_SV
`define BRIDGE_AHB_APB_COVERAGE_SV
class bridge_coverage extends uvm_subscriber #(ahb_seq_item);
  `uvm_component_utils(bridge_coverage)
  ahb_seq_item item;
  covergroup bridge_cg;
    cp_op:   coverpoint item.op    { bins wr={AHB_MST_WRITE}; bins rd={AHB_MST_READ}; }
    cp_resp: coverpoint item.hresp { bins ok={0}; bins err={1}; }
    cx: cross cp_op, cp_resp;
  endgroup
  function new(string name = "bridge_coverage", uvm_component parent = null);
    super.new(name, parent);
    bridge_cg = new();
  endfunction
  function void write(ahb_seq_item t); item = t; bridge_cg.sample(); endfunction
endclass
`endif
