`ifndef AXI4_LITE_SCOREBOARD_SV
`define AXI4_LITE_SCOREBOARD_SV
class axi4_lite_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_lite_scoreboard)
  uvm_analysis_imp #(axi4_lite_seq_item, axi4_lite_scoreboard) analysis_export;
  bit [31:0] ref_mem [bit[31:0]];
  int        pass_count, fail_count;
  function new(string name = "axi4_lite_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction
  function void write(axi4_lite_seq_item item);
    if (item.op == AXI4L_WRITE) begin
      bit [31:0] old = ref_mem.exists(item.addr) ? ref_mem[item.addr] : 32'h0;
      for (int b = 0; b < 4; b++)
        if (item.strb[b]) old[b*8 +: 8] = item.data[b*8 +: 8];
      ref_mem[item.addr] = old;
    end else begin
      bit [31:0] exp = ref_mem.exists(item.addr) ? ref_mem[item.addr] : 32'h0;
      if (item.data !== exp) begin
        `uvm_error("SB", $sformatf("MISMATCH addr=0x%08h exp=0x%08h got=0x%08h", item.addr, exp, item.data))
        fail_count++;
      end else pass_count++;
    end
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("AXI4L SB: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0) `uvm_error("SB", "TEST FAILED")
    else                `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction
endclass
`endif
