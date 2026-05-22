`ifndef AHB_SCOREBOARD_SV
`define AHB_SCOREBOARD_SV

class ahb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ahb_scoreboard)

  uvm_analysis_imp #(ahb_seq_item, ahb_scoreboard) analysis_export;

  bit [31:0] ref_mem [bit[31:0]];
  int        pass_count, fail_count;

  function new(string name = "ahb_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(ahb_seq_item item);
    bit [31:0] curr_addr = item.addr;
    if (item.op == AHB_WRITE) begin
      foreach (item.data[i]) begin
        ref_mem[curr_addr] = item.data[i];
        curr_addr += 4;
      end
      `uvm_info("SB", $sformatf("WR addr=0x%08h beats=%0d", item.addr, item.data.size()), UVM_HIGH)
    end else begin
      foreach (item.data[i]) begin
        bit [31:0] exp = ref_mem.exists(curr_addr) ? ref_mem[curr_addr] : 32'h0;
        if (item.data[i] !== exp) begin
          `uvm_error("SB", $sformatf("READ MISMATCH addr=0x%08h exp=0x%08h got=0x%08h",
                                      curr_addr, exp, item.data[i]))
          fail_count++;
        end else pass_count++;
        curr_addr += 4;
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("AHB SB: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0) `uvm_error("SB", "TEST FAILED")
    else                `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction

endclass

`endif
