`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import uart_agent_pkg::*;
`include "uart_scoreboard.sv"
`include "uart_coverage.sv"
`include "uart_env.sv"
`include "uart_base_seq.sv"
`include "uart_single_byte_seq.sv"
`include "uart_multi_byte_seq.sv"
`include "uart_base_test.sv"
`include "uart_single_test.sv"
`include "uart_multi_test.sv"

module tb_top;
  parameter CLK_PERIOD = 20; // 50MHz
  logic clk, rst_n;
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
  initial begin rst_n = 0; repeat(10) @(posedge clk); rst_n = 1; end

  uart_if uart_vif(.clk(clk), .rst_n(rst_n));

  logic tx_to_rx; // loopback

  uart_top #(.CLK_FREQ(50_000_000), .BAUD_RATE(115_200)) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .tx_data  (uart_vif.tx_data),
    .tx_valid (uart_vif.tx_valid),
    .tx_ready (uart_vif.tx_ready),
    .tx       (uart_vif.tx),
    .rx       (uart_vif.tx),   // loopback: TX feeds RX
    .rx_data  (uart_vif.rx_data),
    .rx_valid (uart_vif.rx_valid)
  );

  assign uart_vif.rx = uart_vif.tx; // expose loopback on interface too

  initial begin
    uvm_config_db #(virtual uart_if.master_mp)::set(null, "uvm_test_top.env.agent.drv", "vif", uart_vif.master_mp);
    uvm_config_db #(virtual uart_if.monitor_mp)::set(null, "uvm_test_top.env.agent.mon", "vif", uart_vif.monitor_mp);
    run_test();
  end
  initial begin #10_000_000; `uvm_fatal("TIMEOUT", "Simulation timeout!") end
endmodule
