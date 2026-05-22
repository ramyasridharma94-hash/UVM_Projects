`ifndef SPI_SCOREBOARD_SV
`define SPI_SCOREBOARD_SV

class spi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(spi_scoreboard)

  uvm_analysis_imp #(spi_seq_item, spi_scoreboard) analysis_export;

  bit [7:0] ref_regs [0:7];
  int       pass_count, fail_count;

  function new(string name = "spi_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    foreach (ref_regs[i]) ref_regs[i] = 8'h0;
  endfunction

  function void write(spi_seq_item item);
    if (item.op == SPI_WRITE) begin
      foreach (item.data[i]) begin
        ref_regs[(item.addr + i) & 7] = item.data[i];
      end
      `uvm_info("SB", $sformatf("SPI WR addr=0x%02h bytes=%0d", item.addr, item.data.size()), UVM_HIGH)
    end else begin
      foreach (item.data[i]) begin
        bit [7:0] exp = ref_regs[(item.addr + i) & 7];
        if (item.data[i] !== exp) begin
          `uvm_error("SB", $sformatf("SPI READ MISMATCH addr=0x%02h exp=0x%02h got=0x%02h",
                                      (item.addr+i)&7, exp, item.data[i]))
          fail_count++;
        end else pass_count++;
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("SPI SB: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0) `uvm_error("SB", "TEST FAILED")
    else                `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction

endclass

`endif
