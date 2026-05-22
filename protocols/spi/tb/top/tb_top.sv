`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import spi_agent_pkg::*;
`include "spi_scoreboard.sv"
`include "spi_coverage.sv"
`include "spi_env.sv"
`include "spi_base_seq.sv"
`include "spi_single_byte_seq.sv"
`include "spi_multi_byte_seq.sv"
`include "spi_base_test.sv"
`include "spi_single_test.sv"
`include "spi_multi_test.sv"

module tb_top;
  parameter CLK_PERIOD = 10;
  logic clk, rst_n;
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
  initial begin rst_n = 0; repeat(5) @(posedge clk); rst_n = 1; end

  spi_if spi_vif(.clk(clk), .rst_n(rst_n));

  // Connect physical SCLK/CS_N/MOSI to DUT
  spi_slave #(.REG_DEPTH(8)) dut (
    .sclk  (spi_vif.sclk),
    .cs_n  (spi_vif.cs_n),
    .mosi  (spi_vif.mosi),
    .miso  (spi_vif.miso)
  );

  initial begin
    uvm_config_db #(virtual spi_if.master_mp)::set(null, "uvm_test_top.env.agent.drv", "vif", spi_vif.master_mp);
    uvm_config_db #(virtual spi_if.monitor_mp)::set(null, "uvm_test_top.env.agent.mon", "vif", spi_vif.monitor_mp);
    run_test();
  end
  initial begin #1_000_000; `uvm_fatal("TIMEOUT", "Simulation timeout!") end
endmodule
