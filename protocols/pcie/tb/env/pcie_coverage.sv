`ifndef PCIE_COVERAGE_SV
`define PCIE_COVERAGE_SV

// PCIe Functional Coverage — covers TLP types, TC, link states, errors, FC, MSI
class pcie_coverage extends uvm_subscriber #(pcie_tlp_seq_item);
  `uvm_component_utils(pcie_coverage)

  import pcie_pkg::*;

  pcie_tlp_seq_item item;

  // -----------------------------------------------------------------------
  // Covergroups
  // -----------------------------------------------------------------------

  // TLP type coverage
  covergroup cg_tlp_type;
    cp_type: coverpoint item.tlp_type {
      bins mem_rd32   = {MRd32};
      bins mem_rd64   = {MRd64};
      bins mem_rdlk32 = {MRdLk32};
      bins mem_rdlk64 = {MRdLk64};
      bins mem_wr32   = {MWr32};
      bins mem_wr64   = {MWr64};
      bins io_rd      = {IORd};
      bins io_wr      = {IOWr};
      bins cfg_rd0    = {CfgRd0};
      bins cfg_wr0    = {CfgWr0};
      bins cfg_rd1    = {CfgRd1};
      bins cfg_wr1    = {CfgWr1};
      bins msg        = {Msg};
      bins msgd       = {MsgD};
      bins cpl        = {Cpl};
      bins cpld       = {CplD};
      bins cpllk      = {CplLk};
      bins cpldlk     = {CplDLk};
      bins fetchadd32 = {FetchAdd32};
      bins fetchadd64 = {FetchAdd64};
      bins swap32     = {Swap32};
      bins swap64     = {Swap64};
      bins cas32      = {CAS32};
      bins cas64      = {CAS64};
    }
  endgroup

  // Traffic Class coverage
  covergroup cg_traffic_class;
    cp_tc: coverpoint item.tc {
      bins tc0 = {3'h0};
      bins tc1 = {3'h1};
      bins tc2 = {3'h2};
      bins tc3 = {3'h3};
      bins tc4 = {3'h4};
      bins tc5 = {3'h5};
      bins tc6 = {3'h6};
      bins tc7 = {3'h7};
    }
  endgroup

  // TLP length range coverage
  covergroup cg_tlp_length;
    cp_len: coverpoint item.length {
      bins len_1dw       = {10'd1};
      bins len_2_4dw     = {[10'd2:10'd4]};
      bins len_5_16dw    = {[10'd5:10'd16]};
      bins len_17_64dw   = {[10'd17:10'd64]};
      bins len_65_256dw  = {[10'd65:10'd256]};
      bins len_max       = {10'd1023, 10'd0};
    }
  endgroup

  // Completion status coverage
  covergroup cg_cpl_status;
    cp_status: coverpoint item.cpl_status {
      bins sc  = {CPL_SC};
      bins ur  = {CPL_UR};
      bins crs = {CPL_CRS};
      bins ca  = {CPL_CA};
    }
  endgroup

  // Error injection coverage
  covergroup cg_errors;
    cp_err: coverpoint item.inject_err {
      bins none         = {ERR_NONE};
      bins ecrc         = {ERR_ECRC};
      bins bad_tlp      = {ERR_BAD_TLP};
      bins bad_dllp     = {ERR_BAD_DLLP};
      bins replay_rlvr  = {ERR_REPLAY_ROLLOVER};
      bins replay_tmo   = {ERR_REPLAY_TIMEOUT};
      bins malformed    = {ERR_MALFORMED_TLP};
      bins unsupported  = {ERR_UNSUPPORTED_REQ};
      bins cpl_abort    = {ERR_COMPLETER_ABORT};
      bins unexp_cpl    = {ERR_UNEXPECTED_CPL};
      bins rx_overflow  = {ERR_RECEIVER_OVERFLOW};
      bins poisoned     = {ERR_POISONED_TLP};
      bins dll_proto    = {ERR_DATA_LINK_PROTO};
      bins surprise_dn  = {ERR_SURPRISE_DOWN};
    }
  endgroup

  // Attribute bits coverage
  covergroup cg_tlp_attr;
    cp_attr: coverpoint item.attr {
      bins no_attr     = {2'b00};
      bins relax_only  = {2'b01};
      bins nosnoop_only= {2'b10};
      bins both        = {2'b11};
    }
    cp_ep: coverpoint item.ep;
    cp_ecrc: coverpoint item.ecrc_en;
  endgroup

  // Address space coverage (32b vs 64b)
  covergroup cg_addr_space;
    cp_upper: coverpoint item.addr[63:32] {
      bins zero_upper = {32'h0};
      bins nonzero_up = default;
    }
    cp_aligned: coverpoint item.addr[1:0] {
      bins dw_aligned = {2'b00};
    }
  endgroup

  // Byte Enable coverage
  covergroup cg_byte_enables;
    cp_fbe: coverpoint item.first_be {
      bins full  = {4'hF};
      bins byte0 = {4'h1};
      bins byte3 = {4'h8};
      bins byte01= {4'h3};
      bins other = default;
    }
    cp_lbe: coverpoint item.last_be {
      bins zero  = {4'h0};
      bins full  = {4'hF};
      bins other = default;
    }
  endgroup

  // Cross coverage: TLP type × TC
  covergroup cg_cross_type_tc;
    cp_type: coverpoint item.tlp_type {
      bins posted    = {MWr32, MWr64, Msg, MsgD};
      bins np        = {MRd32, MRd64, IORd, IOWr, CfgRd0, CfgRd1};
      bins cpl_bins  = {Cpl, CplD};
      bins atomic    = {FetchAdd32, FetchAdd64, Swap32, Swap64, CAS32, CAS64};
    }
    cp_tc: coverpoint item.tc;
    cx_type_tc: cross cp_type, cp_tc;
  endgroup

  // Tag space coverage
  covergroup cg_tag;
    cp_tag_lo: coverpoint item.tag[7:0] {
      bins zero    = {8'h00};
      bins max     = {8'hFF};
      bins mid     = {[8'h01:8'hFE]};
    }
    cp_ext_tag: coverpoint item.tag[9:8] {
      bins tag_8bit  = {2'b00};
      bins ext_tag9  = {2'b01};
      bins ext_tag10 = {[2'b10:2'b11]};
    }
  endgroup

  // -----------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_tlp_type   = new();
    cg_traffic_class = new();
    cg_tlp_length = new();
    cg_cpl_status = new();
    cg_errors     = new();
    cg_tlp_attr   = new();
    cg_addr_space = new();
    cg_byte_enables = new();
    cg_cross_type_tc = new();
    cg_tag        = new();
  endfunction

  function void write(pcie_tlp_seq_item t);
    item = t;
    cg_tlp_type.sample();
    cg_traffic_class.sample();
    cg_tlp_length.sample();
    cg_cpl_status.sample();
    cg_errors.sample();
    cg_tlp_attr.sample();
    cg_addr_space.sample();
    cg_byte_enables.sample();
    cg_cross_type_tc.sample();
    cg_tag.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf(
      "\n=== PCIe Coverage Summary ===\n"
      "  TLP Type Coverage   : %.1f%%\n"
      "  Traffic Class       : %.1f%%\n"
      "  TLP Length          : %.1f%%\n"
      "  Completion Status   : %.1f%%\n"
      "  Error Types         : %.1f%%\n"
      "  TLP Attributes      : %.1f%%\n"
      "  Address Space       : %.1f%%\n"
      "  Byte Enables        : %.1f%%\n"
      "  Type×TC Cross       : %.1f%%\n"
      "  Tag Space           : %.1f%%",
      cg_tlp_type.get_inst_coverage(),
      cg_traffic_class.get_inst_coverage(),
      cg_tlp_length.get_inst_coverage(),
      cg_cpl_status.get_inst_coverage(),
      cg_errors.get_inst_coverage(),
      cg_tlp_attr.get_inst_coverage(),
      cg_addr_space.get_inst_coverage(),
      cg_byte_enables.get_inst_coverage(),
      cg_cross_type_tc.get_inst_coverage(),
      cg_tag.get_inst_coverage()), UVM_LOW)
  endfunction

endclass : pcie_coverage

`endif
