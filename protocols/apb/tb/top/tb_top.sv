`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import apb_agent_pkg::*;
`include "apb_scoreboard.sv"
`include "apb_coverage.sv"
`include "apb_env.sv"
`include "apb_base_seq.sv"
`include "apb_write_seq.sv"
`include "apb_read_seq.sv"
`include "apb_base_test.sv"
`include "apb_write_test.sv"
`include "apb_read_test.sv"

module tb_top;
  parameter CLK_PERIOD = 10;
  logic clk, rst_n;
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
  initial begin rst_n = 0; repeat(5) @(posedge clk); rst_n = 1; end

  apb_if #(.DATA_WIDTH(32), .ADDR_WIDTH(32)) apb_vif(.clk(clk), .rst_n(rst_n));

  apb_slave #(.DATA_WIDTH(32), .ADDR_WIDTH(32), .MEM_DEPTH(8)) dut (
    .pclk    (clk),    .presetn  (rst_n),
    .paddr   (apb_vif.paddr),   .psel     (apb_vif.psel),
    .penable (apb_vif.penable), .pwrite   (apb_vif.pwrite),
    .pwdata  (apb_vif.pwdata),  .prdata   (apb_vif.prdata),
    .pready  (apb_vif.pready),  .pslverr  (apb_vif.pslverr)
  );

  initial begin
    uvm_config_db #(virtual apb_if.master_mp)::set(null, "uvm_test_top.env.agent.drv", "vif", apb_vif.master_mp);
    uvm_config_db #(virtual apb_if.monitor_mp)::set(null, "uvm_test_top.env.agent.mon", "vif", apb_vif.monitor_mp);
    run_test();
  end
  initial begin #500_000; `uvm_fatal("TIMEOUT", "Simulation timeout!") end
endmodule
