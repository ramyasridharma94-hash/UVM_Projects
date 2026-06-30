`ifndef PCIE_TLP_SEQ_ITEM_SV
`define PCIE_TLP_SEQ_ITEM_SV

// PCIe TLP Sequence Item — covers all TLP types per PCIe Base Spec
class pcie_tlp_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(pcie_tlp_seq_item)
    `uvm_field_enum(tlp_type_e,     tlp_type,    UVM_ALL_ON)
    `uvm_field_int (addr,                         UVM_ALL_ON)
    `uvm_field_int (length,                       UVM_ALL_ON)
    `uvm_field_int (tc,                           UVM_ALL_ON)
    `uvm_field_int (attr,                         UVM_ALL_ON)
    `uvm_field_int (req_id,                       UVM_ALL_ON)
    `uvm_field_int (tag,                          UVM_ALL_ON)
    `uvm_field_int (first_be,                     UVM_ALL_ON)
    `uvm_field_int (last_be,                      UVM_ALL_ON)
    `uvm_field_int (msg_code,                     UVM_ALL_ON)
    `uvm_field_int (ep,                           UVM_ALL_ON)
    `uvm_field_int (ecrc_en,                      UVM_ALL_ON)
    `uvm_field_int (data_lo,                      UVM_ALL_ON)
    `uvm_field_int (data_hi,                      UVM_ALL_ON)
    `uvm_field_enum(cpl_status_e,   cpl_status,  UVM_ALL_ON)
    `uvm_field_int (cpl_req_id,                   UVM_ALL_ON)
    `uvm_field_int (cpl_tag,                      UVM_ALL_ON)
    `uvm_field_int (cpl_byte_cnt,                 UVM_ALL_ON)
    `uvm_field_enum(pcie_error_e,   inject_err,  UVM_ALL_ON)
    `uvm_field_int (at,                           UVM_ALL_ON)
    `uvm_field_int (th,                           UVM_ALL_ON)
    `uvm_field_int (ln,                           UVM_ALL_ON)
  `uvm_object_utils_end

  import pcie_pkg::*;

  // -----------------------------------------------------------------------
  // Randomizable fields
  // -----------------------------------------------------------------------
  rand tlp_type_e   tlp_type;
  rand logic [63:0] addr;
  rand logic [9:0]  length;        // payload length in DWs (0 = 1024 DW)
  rand logic [2:0]  tc;            // traffic class 0-7
  rand logic [1:0]  attr;          // {no_snoop, relaxed_order}
  rand logic [15:0] req_id;        // {bus[7:0], dev[4:0], fn[2:0]}
  rand logic [9:0]  tag;           // 10-bit extended tag
  rand logic [3:0]  first_be;
  rand logic [3:0]  last_be;
  rand logic [2:0]  msg_code;
  rand logic        ep;            // error poisoned
  rand logic        ecrc_en;
  rand logic [63:0] data_lo;
  rand logic [63:0] data_hi;
  // Completion fields
  rand cpl_status_e cpl_status;
  rand logic [15:0] cpl_req_id;
  rand logic [7:0]  cpl_tag;
  rand logic [11:0] cpl_byte_cnt;
  // Error injection
  rand pcie_error_e inject_err;
  // Optional TLP hint fields
  rand logic [1:0]  at;            // address type (for ATS)
  rand logic        th;            // TLP hints
  rand logic        ln;            // lightweight notification

  // -----------------------------------------------------------------------
  // Constraints
  // -----------------------------------------------------------------------
  // Default: no error injection, no poisoning
  constraint c_no_err_default { inject_err == ERR_NONE; ep == 0; }

  // Reasonable length (1-32 DW for most tests)
  constraint c_length_range {
    length inside {[1:32]};
  }

  // MWr/IORd/IOWr: length must be ≥1
  constraint c_length_write {
    (tlp_type inside {MWr32, MWr64, IOWr}) -> length >= 1;
  }

  // MRd/IORd: no payload (has_data=0), length ≥1
  constraint c_mrd_length {
    (tlp_type inside {MRd32, MRd64, IORd}) -> length inside {[1:8]};
  }

  // Config R/W: length = 1 DW
  constraint c_cfg_length {
    (tlp_type inside {CfgRd0, CfgRd1, CfgWr0, CfgWr1}) -> length == 1;
  }

  // 64-bit address: upper 32b non-zero for 64b types
  constraint c_addr_4dw {
    (tlp_type inside {MRd64, MWr64, FetchAdd64, Swap64, CAS64}) ->
      addr[63:32] != 32'h0;
  }
  constraint c_addr_3dw {
    (tlp_type inside {MRd32, MWr32, IORd, IOWr, FetchAdd32, Swap32, CAS32,
                      CfgRd0, CfgRd1, CfgWr0, CfgWr1}) ->
      addr[63:32] == 32'h0;
  }

  // Completion: status distribution
  constraint c_cpl_status_dist {
    (tlp_type inside {Cpl, CplD, CplLk, CplDLk}) ->
      cpl_status dist {CPL_SC := 80, CPL_UR := 10, CPL_CA := 5, CPL_CRS := 5};
  }

  // ECRC enabled 20% of time
  constraint c_ecrc_dist { ecrc_en dist {1 := 20, 0 := 80}; }

  // TC distribution (TC0 most common)
  constraint c_tc_dist { tc dist {3'h0 := 50, 3'h1 := 15, 3'h2 := 10,
                                   3'h3 := 10, 3'h4 := 5, 3'h5 := 5,
                                   3'h6 := 3,  3'h7 := 2}; }

  // first_be always non-zero for single-DW transfers
  constraint c_first_be { first_be != 4'h0; }

  // last_be = 0 for length-1 transfers
  constraint c_last_be_zero { (length == 1) -> last_be == 4'h0; }

  // -----------------------------------------------------------------------
  function new(string name = "pcie_tlp_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf(
      "type=%-10s addr=0x%016h len=%0d tc=%0d tag=0x%02h ep=%0b ecrc=%0b cpl_sts=%s err=%s",
      tlp_type.name(), addr, length, tc, tag, ep, ecrc_en,
      cpl_status.name(), inject_err.name());
  endfunction

  // Helper: is this TLP a posted transaction?
  function bit is_posted();
    return tlp_type inside {MWr32, MWr64, Msg, MsgD};
  endfunction

  // Helper: is this TLP a completion?
  function bit is_completion();
    return tlp_type inside {Cpl, CplD, CplLk, CplDLk};
  endfunction

  // Helper: does this TLP carry a data payload?
  function bit has_data();
    return tlp_type inside {MWr32, MWr64, IOWr, CfgWr0, CfgWr1, MsgD,
                             CplD, CplDLk, FetchAdd32, FetchAdd64,
                             Swap32, Swap64, CAS32, CAS64};
  endfunction

endclass : pcie_tlp_seq_item

`endif
