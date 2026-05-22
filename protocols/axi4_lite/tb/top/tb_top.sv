`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import axi4_lite_agent_pkg::*;
`include "axi4_lite_scoreboard.sv"
`include "axi4_lite_coverage.sv"
`include "axi4_lite_env.sv"
`include "axi4_lite_base_seq.sv"
`include "axi4_lite_write_seq.sv"
`include "axi4_lite_read_seq.sv"
`include "axi4_lite_base_test.sv"
`include "axi4_lite_write_test.sv"
`include "axi4_lite_read_test.sv"

module tb_top;
  parameter CLK_PERIOD = 10;
  logic clk, rst_n;
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
  initial begin rst_n = 0; repeat(5) @(posedge clk); rst_n = 1; end

  axi4_lite_if #(.DATA_WIDTH(32), .ADDR_WIDTH(32)) axil_if(.clk(clk), .rst_n(rst_n));

  axi4_lite_slave #(.DATA_WIDTH(32), .ADDR_WIDTH(32), .MEM_DEPTH(8)) dut (
    .aclk    (clk),    .aresetn (rst_n),
    .awaddr  (axil_if.awaddr),  .awvalid (axil_if.awvalid), .awready (axil_if.awready),
    .wdata   (axil_if.wdata),   .wstrb   (axil_if.wstrb),
    .wvalid  (axil_if.wvalid),  .wready  (axil_if.wready),
    .bresp   (axil_if.bresp),   .bvalid  (axil_if.bvalid),  .bready  (axil_if.bready),
    .araddr  (axil_if.araddr),  .arvalid (axil_if.arvalid), .arready (axil_if.arready),
    .rdata   (axil_if.rdata),   .rresp   (axil_if.rresp),
    .rvalid  (axil_if.rvalid),  .rready  (axil_if.rready)
  );

  initial begin
    uvm_config_db #(virtual axi4_lite_if.master_mp)::set(null, "uvm_test_top.env.agent.drv", "vif", axil_if.master_mp);
    uvm_config_db #(virtual axi4_lite_if.monitor_mp)::set(null, "uvm_test_top.env.agent.mon", "vif", axil_if.monitor_mp);
    run_test();
  end
  initial begin #500_000; `uvm_fatal("TIMEOUT", "Simulation timeout!") end
endmodule
