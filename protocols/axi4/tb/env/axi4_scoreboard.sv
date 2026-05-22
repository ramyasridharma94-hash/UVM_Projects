`ifndef AXI4_SCOREBOARD_SV
`define AXI4_SCOREBOARD_SV

class axi4_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard)

  uvm_analysis_imp #(axi4_seq_item, axi4_scoreboard) analysis_export;

  // Internal reference memory (mirrors DUT memory)
  bit [31:0] ref_mem [bit[31:0]];
  int        pass_count, fail_count;

  function new(string name = "axi4_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    pass_count = 0;
    fail_count = 0;
  endfunction

  function void write(axi4_seq_item item);
    if (item.op == AXI4_WRITE) begin
      bit [31:0] curr_addr = item.addr;
      foreach (item.data[i]) begin
        bit [31:0] old_val = ref_mem.exists(curr_addr) ? ref_mem[curr_addr] : 32'h0;
        bit [31:0] new_val = old_val;
        for (int b = 0; b < 4; b++)
          if (item.strb[i][b]) new_val[b*8 +: 8] = item.data[i][b*8 +: 8];
        ref_mem[curr_addr] = new_val;
        curr_addr += 4;
      end
      if (item.resp == 2'b00)
        `uvm_info("SB", $sformatf("WRITE OKAY: addr=0x%08h beats=%0d", item.addr, item.data.size()), UVM_MEDIUM)
      else begin
        `uvm_error("SB", $sformatf("WRITE ERROR resp: addr=0x%08h resp=%0b", item.addr, item.resp))
        fail_count++;
      end
    end else begin
      // READ: compare against ref_mem
      bit [31:0] curr_addr = item.addr;
      foreach (item.data[i]) begin
        bit [31:0] exp_data = ref_mem.exists(curr_addr) ? ref_mem[curr_addr] : 32'h0;
        if (item.data[i] !== exp_data) begin
          `uvm_error("SB", $sformatf("READ MISMATCH addr=0x%08h exp=0x%08h got=0x%08h",
                                      curr_addr, exp_data, item.data[i]))
          fail_count++;
        end else begin
          `uvm_info("SB", $sformatf("READ MATCH   addr=0x%08h data=0x%08h", curr_addr, item.data[i]), UVM_HIGH)
          pass_count++;
        end
        curr_addr += 4;
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("Scoreboard: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0)
      `uvm_error("SB", "TEST FAILED: scoreboard mismatches detected")
    else
      `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction

endclass

`endif
