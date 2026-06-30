`ifndef APB_BRIDGE_COVERAGE_SV
`define APB_BRIDGE_COVERAGE_SV

class bridge_coverage extends uvm_subscriber #(pcie_tlp_seq_item);
  `uvm_component_utils(bridge_coverage)
  import pcie_pkg::*;

  pcie_tlp_seq_item item;

  covergroup cg_tlp_type;
    cp: coverpoint item.tlp_type {
      bins cfg_rd = {CfgRd0}; bins cfg_wr = {CfgWr0};
      bins mem_rd = {MRd32};  bins mem_wr = {MWr32};
    }
  endgroup

  covergroup cg_first_be;
    cp: coverpoint item.first_be {
      bins full={4'hF}; bins byte0={4'h1}; bins byte3={4'h8};
      bins half_lo={4'h3}; bins half_hi={4'hC}; bins other=default;
    }
  endgroup

  covergroup cg_slverr;
    cp: coverpoint item.inject_slverr { bins no_err={0}; bins err={1}; }
  endgroup

  covergroup cg_addr_range;
    cp: coverpoint item.addr[11:2] {
      bins reg_0_7  = {[10'h000:10'h007]};
      bins reg_8_15 = {[10'h008:10'h00F]};
      bins reg_hi   = default;
    }
  endgroup

  covergroup cg_cross_type_be;
    cp_t: coverpoint item.tlp_type { bins rd={CfgRd0,MRd32}; bins wr={CfgWr0,MWr32}; }
    cp_b: coverpoint item.first_be;
    cx: cross cp_t, cp_b;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_tlp_type  = new(); cg_first_be = new();
    cg_slverr    = new(); cg_addr_range = new();
    cg_cross_type_be = new();
  endfunction

  function void write(pcie_tlp_seq_item t);
    item = t;
    cg_tlp_type.sample(); cg_first_be.sample();
    cg_slverr.sample();   cg_addr_range.sample();
    cg_cross_type_be.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV",$sformatf(
      "\n=== APB Bridge Coverage ===\n"
      "  TLP Type  : %.1f%%\n  Byte Enable: %.1f%%\n"
      "  SlvErr    : %.1f%%\n  Addr Range : %.1f%%\n  Type×BE   : %.1f%%",
      cg_tlp_type.get_inst_coverage(), cg_first_be.get_inst_coverage(),
      cg_slverr.get_inst_coverage(),   cg_addr_range.get_inst_coverage(),
      cg_cross_type_be.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

`endif
