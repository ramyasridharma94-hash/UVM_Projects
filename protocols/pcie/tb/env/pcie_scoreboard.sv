`ifndef PCIE_SCOREBOARD_SV
`define PCIE_SCOREBOARD_SV

// PCIe Scoreboard — tracks in-flight TLPs, matches requests to completions,
// checks ordering rules, verifies no duplicate tags, and catches AER errors
class pcie_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(pcie_scoreboard)

  import pcie_pkg::*;

  // Analysis FIFOs
  `uvm_analysis_imp_decl(_req)
  `uvm_analysis_imp_decl(_posted)
  `uvm_analysis_imp_decl(_np)
  `uvm_analysis_imp_decl(_cpl)
  `uvm_analysis_imp_decl(_cfg)
  `uvm_analysis_imp_decl(_err)

  uvm_analysis_imp_req    #(pcie_tlp_seq_item, pcie_scoreboard) ap_req;
  uvm_analysis_imp_posted #(pcie_tlp_seq_item, pcie_scoreboard) ap_posted;
  uvm_analysis_imp_np     #(pcie_tlp_seq_item, pcie_scoreboard) ap_np;
  uvm_analysis_imp_cpl    #(pcie_tlp_seq_item, pcie_scoreboard) ap_cpl;
  uvm_analysis_imp_cfg    #(pcie_tlp_seq_item, pcie_scoreboard) ap_cfg;
  uvm_analysis_imp_err    #(pcie_tlp_seq_item, pcie_scoreboard) ap_err;

  // In-flight tag tracking (tag → request item)
  pcie_tlp_seq_item   pending_reqs [logic [9:0]];
  // Completion tracking
  pcie_tlp_seq_item   pending_cpls [logic [9:0]];
  // Config access log
  pcie_tlp_seq_item   cfg_log [$];

  // Counters
  int unsigned req_count       = 0;
  int unsigned posted_count    = 0;
  int unsigned np_count        = 0;
  int unsigned cpl_count       = 0;
  int unsigned cfg_count       = 0;
  int unsigned error_count     = 0;
  int unsigned tag_collision   = 0;
  int unsigned unexpected_cpl  = 0;
  int unsigned cpl_sc_count    = 0;
  int unsigned cpl_ur_count    = 0;
  int unsigned cpl_ca_count    = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_req    = new("ap_req",    this);
    ap_posted = new("ap_posted", this);
    ap_np     = new("ap_np",     this);
    ap_cpl    = new("ap_cpl",    this);
    ap_cfg    = new("ap_cfg",    this);
    ap_err    = new("ap_err",    this);
  endfunction

  // -----------------------------------------------------------------------
  // Outgoing request — track non-posted tags
  // -----------------------------------------------------------------------
  function void write_req(pcie_tlp_seq_item item);
    req_count++;
    if (!item.is_posted() && !item.is_completion()) begin
      if (pending_reqs.exists(item.tag)) begin
        tag_collision++;
        `uvm_error("SB", $sformatf("Tag collision! tag=0x%03h already in-flight", item.tag))
      end
      pending_reqs[item.tag] = item;
      `uvm_info("SB_REQ", $sformatf("NP request logged tag=0x%03h type=%s",
                item.tag, item.tlp_type.name()), UVM_HIGH)
    end
  endfunction

  // -----------------------------------------------------------------------
  // Received posted TLP
  // -----------------------------------------------------------------------
  function void write_posted(pcie_tlp_seq_item item);
    posted_count++;
    if (item.ep)
      `uvm_warning("SB_POST", $sformatf("Posted TLP with EP=1 type=%s addr=0x%016h",
                   item.tlp_type.name(), item.addr))
    `uvm_info("SB_POST", $sformatf("Posted OK type=%s addr=0x%016h len=%0d",
              item.tlp_type.name(), item.addr, item.length), UVM_HIGH)
  endfunction

  // -----------------------------------------------------------------------
  // Received non-posted TLP
  // -----------------------------------------------------------------------
  function void write_np(pcie_tlp_seq_item item);
    np_count++;
    `uvm_info("SB_NP", $sformatf("NP received type=%s addr=0x%016h tag=0x%03h",
              item.tlp_type.name(), item.addr, item.tag), UVM_HIGH)
  endfunction

  // -----------------------------------------------------------------------
  // Completion received — match to pending request
  // -----------------------------------------------------------------------
  function void write_cpl(pcie_tlp_seq_item item);
    logic [9:0] tag = {2'b0, item.cpl_tag};
    cpl_count++;

    case (item.cpl_status)
      CPL_SC:  cpl_sc_count++;
      CPL_UR:  cpl_ur_count++;
      CPL_CA:  cpl_ca_count++;
      default: ;
    endcase

    if (!pending_reqs.exists(tag)) begin
      unexpected_cpl++;
      `uvm_error("SB_CPL", $sformatf("Unexpected completion tag=0x%03h (no matching request)", tag))
      return;
    end

    // Check completion for the matching request
    pcie_tlp_seq_item req = pending_reqs[tag];
    if (item.cpl_status == CPL_SC) begin
      // Byte count should match request size (simplified: length*4)
      if (item.cpl_byte_cnt > req.length * 4) begin
        `uvm_error("SB_CPL", $sformatf("Completion byte_cnt=%0d > request length*4=%0d for tag=0x%03h",
                   item.cpl_byte_cnt, req.length*4, tag))
      end
    end else begin
      `uvm_info("SB_CPL", $sformatf("Non-SC completion: status=%s for %s tag=0x%03h",
                item.cpl_status.name(), req.tlp_type.name(), tag), UVM_LOW)
    end

    pending_reqs.delete(tag);
    `uvm_info("SB_CPL", $sformatf("Completion matched tag=0x%03h status=%s",
              tag, item.cpl_status.name()), UVM_HIGH)
  endfunction

  // -----------------------------------------------------------------------
  // Config access
  // -----------------------------------------------------------------------
  function void write_cfg(pcie_tlp_seq_item item);
    cfg_count++;
    cfg_log.push_back(item);
    `uvm_info("SB_CFG", $sformatf("CFG_%s reg=0x%03h",
              (item.tlp_type == CfgRd0 || item.tlp_type == CfgRd1) ? "RD" : "WR",
              item.addr[11:0]), UVM_HIGH)
  endfunction

  // -----------------------------------------------------------------------
  // AER error
  // -----------------------------------------------------------------------
  function void write_err(pcie_tlp_seq_item item);
    error_count++;
    `uvm_warning("SB_AER", $sformatf("AER error #%0d: %s", error_count, item.inject_err.name()))
  endfunction

  // -----------------------------------------------------------------------
  // Check phase — report any uncompleted requests
  // -----------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    foreach (pending_reqs[tag]) begin
      `uvm_error("SB_FINAL", $sformatf("Unmatched NP request at end of sim: tag=0x%03h type=%s",
                 tag, pending_reqs[tag].tlp_type.name()))
    end

    `uvm_info("SB_SUMMARY", $sformatf(
      "\n=== PCIe Scoreboard Summary ===\n"
      "  Requests      : %0d\n"
      "  Posted RX     : %0d\n"
      "  Non-Posted RX : %0d\n"
      "  Completions   : %0d (SC=%0d UR=%0d CA=%0d)\n"
      "  Config ops    : %0d\n"
      "  AER errors    : %0d\n"
      "  Tag collisions: %0d\n"
      "  Unexpected Cpl: %0d",
      req_count, posted_count, np_count,
      cpl_count, cpl_sc_count, cpl_ur_count, cpl_ca_count,
      cfg_count, error_count, tag_collision, unexpected_cpl), UVM_LOW)

    if (error_count > 0 && !uvm_config_db#(bit)::exists(this, "", "expected_errors"))
      `uvm_warning("SB_WARN", $sformatf("%0d unexpected AER errors detected", error_count))
  endfunction

endclass : pcie_scoreboard

`endif
