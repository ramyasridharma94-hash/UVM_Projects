`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import ahb_agent_pkg::*;
`include "ahb_scoreboard.sv"
`include "ahb_coverage.sv"
`include "ahb_env.sv"
`include "ahb_base_seq.sv"
`include "ahb_single_seq.sv"
`include "ahb_burst_seq.sv"
`include "ahb_base_test.sv"
`include "ahb_single_test.sv"
`include "ahb_burst_test.sv"

module tb_top;
  parameter CLK_PERIOD = 10;
  logic clk, rst_n;
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
  initial begin rst_n = 0; repeat(5) @(posedge clk); rst_n = 1; end

  ahb_if #(.DATA_WIDTH(32), .ADDR_WIDTH(32)) ahb_vif(.clk(clk), .rst_n(rst_n));

  ahb_slave #(.DATA_WIDTH(32), .ADDR_WIDTH(32), .MEM_DEPTH(16)) dut (
    .hclk    (clk),   .hresetn (rst_n),
    .haddr   (ahb_vif.haddr),  .htrans  (ahb_vif.htrans),
    .hwrite  (ahb_vif.hwrite), .hsize   (ahb_vif.hsize),
    .hburst  (ahb_vif.hburst), .hwdata  (ahb_vif.hwdata),
    .hrdata  (ahb_vif.hrdata), .hready  (ahb_vif.hready),
    .hresp   (ahb_vif.hresp),  .hsel    (ahb_vif.hsel)
  );

  initial begin
    uvm_config_db #(virtual ahb_if.master_mp)::set(null, "uvm_test_top.env.agent.drv", "vif", ahb_vif.master_mp);
    uvm_config_db #(virtual ahb_if.monitor_mp)::set(null, "uvm_test_top.env.agent.mon", "vif", ahb_vif.monitor_mp);
    run_test();
  end
  initial begin #500_000; `uvm_fatal("TIMEOUT", "Simulation timeout!") end
endmodule
