`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import i2c_agent_pkg::*;
`include "i2c_scoreboard.sv"
`include "i2c_coverage.sv"
`include "i2c_env.sv"
`include "i2c_base_seq.sv"
`include "i2c_write_seq.sv"
`include "i2c_read_seq.sv"
`include "i2c_base_test.sv"
`include "i2c_write_test.sv"
`include "i2c_read_test.sv"

module tb_top;
  parameter CLK_PERIOD = 10;
  logic clk, rst_n;
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
  initial begin rst_n = 0; repeat(5) @(posedge clk); rst_n = 1; end

  i2c_if i2c_vif(.clk(clk), .rst_n(rst_n));

  // Pull-up resistors on SDA/SCL
  pullup(i2c_vif.sda);
  pullup(i2c_vif.scl);

  i2c_slave #(.SLAVE_ADDR(7'h50), .REG_DEPTH(8)) dut (
    .scl (i2c_vif.scl),
    .sda (i2c_vif.sda)
  );

  initial begin
    uvm_config_db #(virtual i2c_if.master_mp)::set(null, "uvm_test_top.env.agent.drv", "vif", i2c_vif.master_mp);
    uvm_config_db #(virtual i2c_if.monitor_mp)::set(null, "uvm_test_top.env.agent.mon", "vif", i2c_vif.monitor_mp);
    run_test();
  end
  initial begin #2_000_000; `uvm_fatal("TIMEOUT", "Simulation timeout!") end
endmodule
