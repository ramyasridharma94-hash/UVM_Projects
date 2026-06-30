`ifndef AXI4_BRIDGE_COVERAGE_SV
`define AXI4_BRIDGE_COVERAGE_SV
class bridge_coverage extends uvm_subscriber #(pcie_tlp_seq_item);
  `uvm_component_utils(bridge_coverage)
  import pcie_pkg::*;
  pcie_tlp_seq_item item;

  covergroup cg_tlp_type;
    cp: coverpoint item.tlp_type {
      bins mrd32={MRd32}; bins mrd64={MRd64}; bins mwr32={MWr32}; bins mwr64={MWr64};
      bins iord={IORd};   bins iowr={IOWr};   bins cfgrd={CfgRd0}; bins cfgwr={CfgWr0};
    }
  endgroup
  covergroup cg_length;
    cp: coverpoint item.length { bins one={1}; bins small={[2:4]}; bins med={[5:8]}; bins large={[9:16]}; }
  endgroup
  covergroup cg_addr_space;
    cp: coverpoint item.addr[63:32] { bins lo32={32'h0}; bins hi64=default; }
  endgroup
  covergroup cg_tc;
    cp: coverpoint item.tc { bins tc0={3'h0}; bins tc1={3'h1}; bins tc_hi=default; }
  endgroup
  covergroup cg_cross_type_len;
    cp_t: coverpoint item.tlp_type { bins rd={MRd32,MRd64}; bins wr={MWr32,MWr64}; bins other=default; }
    cp_l: coverpoint item.length { bins single={1}; bins burst=default; }
    cx: cross cp_t, cp_l;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_tlp_type=new(); cg_length=new(); cg_addr_space=new(); cg_tc=new(); cg_cross_type_len=new();
  endfunction
  function void write(pcie_tlp_seq_item t);
    item=t; cg_tlp_type.sample(); cg_length.sample();
    cg_addr_space.sample(); cg_tc.sample(); cg_cross_type_len.sample();
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("COV",$sformatf(
      "\n=== AXI4 Bridge Coverage ===\n  TLP:%.1f%%  Len:%.1f%%  Addr:%.1f%%  TC:%.1f%%  Cross:%.1f%%",
      cg_tlp_type.get_inst_coverage(),cg_length.get_inst_coverage(),
      cg_addr_space.get_inst_coverage(),cg_tc.get_inst_coverage(),
      cg_cross_type_len.get_inst_coverage()),UVM_LOW)
  endfunction
endclass
`endif
