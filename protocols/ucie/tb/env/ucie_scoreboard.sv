`ifndef UCIE_SCOREBOARD_SV
`define UCIE_SCOREBOARD_SV

// Two-sided scoreboard: TX imp captures sent flits, RX imp checks received flits.
`uvm_analysis_imp_decl(_tx)
`uvm_analysis_imp_decl(_rx)

class ucie_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ucie_scoreboard)

  uvm_analysis_imp_tx #(ucie_seq_item, ucie_scoreboard) tx_export;
  uvm_analysis_imp_rx #(ucie_seq_item, ucie_scoreboard) rx_export;

  bit [255:0] exp_q[$]; // queue of flits accepted by DUT TX
  int         pass_count, fail_count;

  function new(string name = "ucie_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_export = new("tx_export", this);
    rx_export = new("rx_export", this);
  endfunction

  // Called when monitor detects DUT accepted a TX flit
  function void write_tx(ucie_seq_item item);
    exp_q.push_back(item.flit_data);
    `uvm_info("SB", $sformatf("Expected enqueued: %s (depth=%0d)", item.convert2string(), exp_q.size()), UVM_HIGH)
  endfunction

  // Called when monitor detects DUT output a RX flit
  function void write_rx(ucie_seq_item item);
    if (exp_q.size() == 0) begin
      `uvm_error("SB", $sformatf("Unexpected RX flit: %s — no expected flit pending", item.convert2string()))
      fail_count++;
    end else begin
      bit [255:0] exp = exp_q.pop_front();
      if (item.flit_data !== exp) begin
        `uvm_error("SB", $sformatf("MISMATCH: exp[63:0]=0x%016h got[63:0]=0x%016h", exp[63:0], item.flit_data[63:0]))
        fail_count++;
      end else begin
        `uvm_info("SB", $sformatf("MATCH: %s", item.convert2string()), UVM_HIGH)
        pass_count++;
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("UCIe SB: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0 || exp_q.size() > 0)
      `uvm_error("SB", $sformatf("TEST FAILED: %0d pending expected flits", exp_q.size()))
    else
      `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction

endclass

`endif
