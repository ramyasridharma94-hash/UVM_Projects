`ifndef AXI4_COVERAGE_SV
`define AXI4_COVERAGE_SV

class axi4_coverage extends uvm_subscriber #(axi4_seq_item);
  `uvm_component_utils(axi4_coverage)

  axi4_seq_item item;

  covergroup axi4_cg;
    cp_op: coverpoint item.op {
      bins write = {AXI4_WRITE};
      bins read  = {AXI4_READ};
    }
    cp_burst: coverpoint item.burst {
      bins incr = {1};
      bins wrap = {2};
    }
    cp_len: coverpoint item.len {
      bins single   = {0};
      bins short[]  = {[1:3]};
      bins medium[] = {[4:7]};
      bins long[]   = {[8:15]};
    }
    cp_resp: coverpoint item.resp {
      bins okay   = {2'b00};
      bins slverr = {2'b10};
    }
    cx_op_burst: cross cp_op, cp_burst;
    cx_op_len:   cross cp_op, cp_len;
  endgroup

  function new(string name = "axi4_coverage", uvm_component parent = null);
    super.new(name, parent);
    axi4_cg = new();
  endfunction

  function void write(axi4_seq_item t);
    item = t;
    axi4_cg.sample();
  endfunction

endclass

`endif
