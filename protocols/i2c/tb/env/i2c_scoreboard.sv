`ifndef I2C_SCOREBOARD_SV
`define I2C_SCOREBOARD_SV

class i2c_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(i2c_scoreboard)

  uvm_analysis_imp #(i2c_seq_item, i2c_scoreboard) analysis_export;

  bit [7:0] ref_regs [0:7];
  int       pass_count, fail_count;

  function new(string name = "i2c_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(i2c_seq_item item);
    if (item.nack) begin
      `uvm_info("SB", "I2C NACK received", UVM_MEDIUM)
      return;
    end
    if (item.op == I2C_WRITE) begin
      foreach (item.data[i])
        ref_regs[(item.reg_addr + i) & 7] = item.data[i];
      `uvm_info("SB", $sformatf("I2C WR saddr=0x%02h raddr=0x%02h", item.slave_addr, item.reg_addr), UVM_HIGH)
    end else begin
      foreach (item.data[i]) begin
        bit [7:0] exp = ref_regs[(item.reg_addr + i) & 7];
        if (item.data[i] !== exp) begin
          `uvm_error("SB", $sformatf("I2C READ MISMATCH reg=%0d exp=0x%02h got=0x%02h",
                                      (item.reg_addr+i)&7, exp, item.data[i]))
          fail_count++;
        end else pass_count++;
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("I2C SB: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0) `uvm_error("SB", "TEST FAILED")
    else                `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction

endclass

`endif
