`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import axi4_agent_pkg::*;

`include "axi4_scoreboard.sv"
`include "axi4_coverage.sv"
`include "axi4_env.sv"
`include "axi4_base_seq.sv"
`include "axi4_write_seq.sv"
`include "axi4_read_seq.sv"
`include "axi4_burst_seq.sv"
`include "axi4_base_test.sv"
`include "axi4_write_test.sv"
`include "axi4_read_test.sv"
`include "axi4_burst_test.sv"

module tb_top;

  parameter CLK_PERIOD = 10;

  logic clk;
  logic rst_n;

  // Clock generation
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  // Reset
  initial begin
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
  end

  // Interface
  axi4_if #(.DATA_WIDTH(32), .ADDR_WIDTH(32), .ID_WIDTH(4)) axi_if(.clk(clk), .rst_n(rst_n));

  // DUT
  axi4_slave #(.DATA_WIDTH(32), .ADDR_WIDTH(32), .ID_WIDTH(4), .MEM_DEPTH(16)) dut (
    .aclk    (clk),
    .aresetn (rst_n),
    .awid    (axi_if.awid),
    .awaddr  (axi_if.awaddr),
    .awlen   (axi_if.awlen),
    .awsize  (axi_if.awsize),
    .awburst (axi_if.awburst),
    .awvalid (axi_if.awvalid),
    .awready (axi_if.awready),
    .wdata   (axi_if.wdata),
    .wstrb   (axi_if.wstrb),
    .wlast   (axi_if.wlast),
    .wvalid  (axi_if.wvalid),
    .wready  (axi_if.wready),
    .bid     (axi_if.bid),
    .bresp   (axi_if.bresp),
    .bvalid  (axi_if.bvalid),
    .bready  (axi_if.bready),
    .arid    (axi_if.arid),
    .araddr  (axi_if.araddr),
    .arlen   (axi_if.arlen),
    .arsize  (axi_if.arsize),
    .arburst (axi_if.arburst),
    .arvalid (axi_if.arvalid),
    .arready (axi_if.arready),
    .rid     (axi_if.rid),
    .rdata   (axi_if.rdata),
    .rresp   (axi_if.rresp),
    .rlast   (axi_if.rlast),
    .rvalid  (axi_if.rvalid),
    .rready  (axi_if.rready)
  );

  // Pass virtual interface to UVM
  initial begin
    uvm_config_db #(virtual axi4_if.master_mp)::set(null, "uvm_test_top.env.agent.drv", "vif", axi_if.master_mp);
    uvm_config_db #(virtual axi4_if.monitor_mp)::set(null, "uvm_test_top.env.agent.mon", "vif", axi_if.monitor_mp);
    run_test();
  end

  // Timeout
  initial begin
    #1_000_000;
    `uvm_fatal("TIMEOUT", "Simulation timeout!")
  end

endmodule
