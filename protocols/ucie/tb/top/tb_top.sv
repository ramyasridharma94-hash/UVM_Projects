`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import ucie_agent_pkg::*;
`include "ucie_scoreboard.sv"
`include "ucie_coverage.sv"
`include "ucie_env.sv"
`include "ucie_base_seq.sv"
`include "ucie_single_flit_seq.sv"
`include "ucie_burst_flit_seq.sv"
`include "ucie_base_test.sv"
`include "ucie_single_flit_test.sv"
`include "ucie_burst_flit_test.sv"

module tb_top;

  parameter CLK_PERIOD = 10; // 100 MHz

  logic clk, rst_n;

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  initial begin
    rst_n = 0;
    repeat (10) @(posedge clk);
    rst_n = 1;
  end

  ucie_if ucie_vif (.clk(clk), .rst_n(rst_n));

  ucie_adapter_top #(
    .FLIT_WIDTH(256),
    .FIFO_DEPTH(8)
  ) dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .tx_flit_data (ucie_vif.tx_flit_data),
    .tx_flit_valid(ucie_vif.tx_flit_valid),
    .tx_flit_ready(ucie_vif.tx_flit_ready),
    .rx_flit_data (ucie_vif.rx_flit_data),
    .rx_flit_valid(ucie_vif.rx_flit_valid)
  );

  initial begin
    uvm_config_db #(virtual ucie_if.master_mp)::set(
      null, "uvm_test_top.env.agent.drv", "vif", ucie_vif.master_mp);
    uvm_config_db #(virtual ucie_if.monitor_mp)::set(
      null, "uvm_test_top.env.agent.mon", "vif", ucie_vif.monitor_mp);
    run_test();
  end

  initial begin
    #1_000_000;
    `uvm_fatal("TIMEOUT", "Simulation timeout!")
  end

endmodule
