`ifndef APB_SCOREBOARD_SV
`define APB_SCOREBOARD_SV

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_seq_item, apb_scoreboard) analysis_export;

  bit [31:0] ref_mem [bit[31:0]];
  int        pass_count, fail_count;

  function new(string name = "apb_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(apb_seq_item item);
    if (item.pslverr) begin
      `uvm_info("SB", $sformatf("PSLVERR at addr=0x%08h (expected)", item.addr), UVM_MEDIUM)
      return;
    end
    if (item.op == APB_WRITE) begin
      ref_mem[item.addr] = item.data;
      `uvm_info("SB", $sformatf("WR addr=0x%08h data=0x%08h", item.addr, item.data), UVM_HIGH)
    end else begin
      bit [31:0] exp = ref_mem.exists(item.addr) ? ref_mem[item.addr] : 32'h0;
      if (item.data !== exp) begin
        `uvm_error("SB", $sformatf("READ MISMATCH addr=0x%08h exp=0x%08h got=0x%08h",
                                    item.addr, exp, item.data))
        fail_count++;
      end else begin
        `uvm_info("SB", $sformatf("READ MATCH addr=0x%08h data=0x%08h", item.addr, item.data), UVM_HIGH)
        pass_count++;
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("APB SB: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0) `uvm_error("SB", "TEST FAILED")
    else                `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction

endclass

`endif
