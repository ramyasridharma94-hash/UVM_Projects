`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import spi_bridge_agent_pkg::*;
import i2c_bridge_agent_pkg::*;
`include "bridge_scoreboard.sv"
`include "bridge_coverage.sv"
`include "bridge_env.sv"
`include "bridge_base_seq.sv"
`include "bridge_write_seq.sv"
`include "bridge_read_seq.sv"
`include "bridge_base_test.sv"
`include "bridge_write_test.sv"
`include "bridge_read_test.sv"

module tb_top;
  parameter CLK_PERIOD = 10;
  logic clk, rst_n;
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
  initial begin rst_n = 0; repeat(5) @(posedge clk); rst_n = 1; end

  spi_if spi_vif(.clk(clk), .rst_n(rst_n));
  i2c_if i2c_vif(.clk(clk), .rst_n(rst_n));

  // Pull-up on I2C SDA
  pullup(i2c_vif.sda);

  // DUT: SPI-to-I2C bridge
  spi_to_i2c_bridge #(.CLK_DIV(4)) dut (
    .sclk (spi_vif.sclk),
    .cs_n (spi_vif.cs_n),
    .mosi (spi_vif.mosi),
    .miso (spi_vif.miso),
    .scl  (i2c_vif.scl),
    .sda  (i2c_vif.sda)
  );

  initial begin
    uvm_config_db #(virtual spi_if.master_mp)::set(null, "uvm_test_top.env.master_agent.drv", "vif", spi_vif.master_mp);
    uvm_config_db #(virtual spi_if.monitor_mp)::set(null, "uvm_test_top.env.master_agent.mon", "vif", spi_vif.monitor_mp);
    uvm_config_db #(virtual i2c_if.monitor_mp)::set(null, "uvm_test_top.env.slave_agent.mon",  "vif", i2c_vif.monitor_mp);
    run_test();
  end
  initial begin #5_000_000; `uvm_fatal("TIMEOUT", "Simulation timeout!") end
endmodule
