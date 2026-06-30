`ifndef APB_BRIDGE_SCOREBOARD_SV
`define APB_BRIDGE_SCOREBOARD_SV

class bridge_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(bridge_scoreboard)
  import pcie_pkg::*;

  `uvm_analysis_imp_decl(_req)
  `uvm_analysis_imp_decl(_apb)
  `uvm_analysis_imp_decl(_cpl)

  uvm_analysis_imp_req #(pcie_tlp_seq_item, bridge_scoreboard) ap_req;
  uvm_analysis_imp_apb #(apb_seq_item,      bridge_scoreboard) ap_apb;
  uvm_analysis_imp_cpl #(pcie_tlp_seq_item, bridge_scoreboard) ap_cpl;

  pcie_tlp_seq_item pending[logic [7:0]];
  int req_cnt, apb_cnt, cpl_cnt, err_cnt;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_req = new("ap_req", this);
    ap_apb = new("ap_apb", this);
    ap_cpl = new("ap_cpl", this);
  endfunction

  function void write_req(pcie_tlp_seq_item it);
    req_cnt++;
    pending[it.tag] = it;
  endfunction

  function void write_apb(apb_seq_item it);
    apb_cnt++;
    `uvm_info("SB_APB", it.convert2string(), UVM_HIGH)
    // Protocol check: SETUP must precede ENABLE — verified by monitor
    if (it.slverr)
      `uvm_info("SB_APB","pslverr=1 — expect CA completion",UVM_LOW)
  endfunction

  function void write_cpl(pcie_tlp_seq_item it);
    cpl_cnt++;
    if (!pending.exists(it.tag)) begin
      err_cnt++;
      `uvm_error("SB_CPL",$sformatf("Unexpected completion tag=0x%02h",it.tag))
      return;
    end
    pending.delete(it.tag);
    `uvm_info("SB_CPL",$sformatf("Matched cpl tag=0x%02h data=0x%08h",it.tag,it.data),UVM_HIGH)
  endfunction

  function void check_phase(uvm_phase phase);
    foreach (pending[t])
      `uvm_error("SB","Unmatched request at end-of-sim")
    `uvm_info("SB_SUMMARY",$sformatf(
      "\n=== APB Bridge Scoreboard ===\n"
      "  Requests : %0d\n  APB xfers: %0d\n  Completions: %0d\n  Errors: %0d",
      req_cnt, apb_cnt, cpl_cnt, err_cnt), UVM_LOW)
  endfunction
endclass

`endif
