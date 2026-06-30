`ifndef AHB_BRIDGE_SCOREBOARD_SV
`define AHB_BRIDGE_SCOREBOARD_SV
class bridge_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(bridge_scoreboard)
  import pcie_pkg::*;
  `uvm_analysis_imp_decl(_req) `uvm_analysis_imp_decl(_ahb) `uvm_analysis_imp_decl(_cpl)
  uvm_analysis_imp_req #(pcie_tlp_seq_item,bridge_scoreboard) ap_req;
  uvm_analysis_imp_ahb #(ahb_seq_item,     bridge_scoreboard) ap_ahb;
  uvm_analysis_imp_cpl #(pcie_tlp_seq_item,bridge_scoreboard) ap_cpl;

  pcie_tlp_seq_item pending[logic [7:0]];
  int req_cnt,ahb_cnt,cpl_cnt,err_cnt;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_req=new("ap_req",this); ap_ahb=new("ap_ahb",this); ap_cpl=new("ap_cpl",this);
  endfunction

  function void write_req(pcie_tlp_seq_item it);
    req_cnt++; pending[it.tag]=it;
  endfunction

  function void write_ahb(ahb_seq_item it);
    ahb_cnt++;
    `uvm_info("SB_AHB",it.convert2string(),UVM_HIGH)
  endfunction

  function void write_cpl(pcie_tlp_seq_item it);
    cpl_cnt++;
    if (!pending.exists(it.tag)) begin
      err_cnt++; `uvm_error("SB_CPL",$sformatf("Unexpected cpl tag=0x%02h",it.tag)); return;
    end
    pending.delete(it.tag);
  endfunction

  function void check_phase(uvm_phase phase);
    foreach (pending[t]) `uvm_error("SB","Unmatched request at end-of-sim")
    `uvm_info("SB_SUMMARY",$sformatf(
      "\n=== AHB Bridge Scoreboard ===\n  Requests:%0d  AHB:%0d  Completions:%0d  Errors:%0d",
      req_cnt,ahb_cnt,cpl_cnt,err_cnt),UVM_LOW)
  endfunction
endclass
`endif
