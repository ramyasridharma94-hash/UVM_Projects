`ifndef APB_COVERAGE_SV
`define APB_COVERAGE_SV
class apb_coverage extends uvm_subscriber #(apb_seq_item);
  `uvm_component_utils(apb_coverage)
  apb_seq_item item;
  covergroup apb_cg;
    cp_op:     coverpoint item.op      { bins wr={APB_WRITE}; bins rd={APB_READ}; }
    cp_slverr: coverpoint item.pslverr { bins ok={0}; bins err={1}; }
    cp_addr:   coverpoint item.addr[4:2] { bins regs[] = {[0:7]}; }
    cx_op_err: cross cp_op, cp_slverr;
  endgroup
  function new(string name = "apb_coverage", uvm_component parent = null);
    super.new(name, parent);
    apb_cg = new();
  endfunction
  function void write(apb_seq_item t); item = t; apb_cg.sample(); endfunction
endclass
`endif
