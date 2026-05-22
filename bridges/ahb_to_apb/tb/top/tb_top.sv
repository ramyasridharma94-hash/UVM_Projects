`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import ahb_mst_agent_pkg::*;
import apb_slv_agent_pkg::*;
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

  ahb_if #(.DATA_WIDTH(32), .ADDR_WIDTH(32)) ahb_vif(.clk(clk), .rst_n(rst_n));
  apb_if #(.DATA_WIDTH(32), .ADDR_WIDTH(32)) apb_vif(.clk(clk), .rst_n(rst_n));

  // APB memory model
  logic [31:0] apb_mem [0:7];
  logic [31:0] prdata_r;
  logic        pready_r;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin pready_r <= 0; prdata_r <= 0; end
    else begin
      pready_r <= apb_vif.psel && apb_vif.penable;
      if (apb_vif.psel && apb_vif.penable) begin
        if (apb_vif.pwrite) apb_mem[(apb_vif.paddr>>2)&7] <= apb_vif.pwdata;
        else                prdata_r <= apb_mem[(apb_vif.paddr>>2)&7];
      end
    end
  end
  assign apb_vif.prdata  = prdata_r;
  assign apb_vif.pready  = pready_r;
  assign apb_vif.pslverr = 1'b0;

  // Wire HREADY_IN from bridge HREADY_OUT
  assign ahb_vif.hready_in = ahb_vif.hready_out;

  ahb_to_apb_bridge dut (
    .hclk      (clk),      .hresetn    (rst_n),
    .s_haddr   (ahb_vif.haddr),   .s_htrans   (ahb_vif.htrans),
    .s_hwrite  (ahb_vif.hwrite),  .s_hsize    (ahb_vif.hsize),
    .s_hburst  (ahb_vif.hburst),  .s_hwdata   (ahb_vif.hwdata),
    .s_hrdata  (ahb_vif.hrdata),  .s_hsel     (ahb_vif.hsel),
    .s_hready_in(ahb_vif.hready_in), .s_hready_out(ahb_vif.hready_out),
    .s_hresp   (ahb_vif.hresp),
    .m_paddr   (apb_vif.paddr),   .m_psel     (apb_vif.psel),
    .m_penable (apb_vif.penable), .m_pwrite   (apb_vif.pwrite),
    .m_pwdata  (apb_vif.pwdata),  .m_prdata   (apb_vif.prdata),
    .m_pready  (apb_vif.pready),  .m_pslverr  (apb_vif.pslverr)
  );

  initial begin
    uvm_config_db #(virtual ahb_if.master_mp)::set(null, "uvm_test_top.env.master_agent.drv", "vif", ahb_vif.master_mp);
    uvm_config_db #(virtual ahb_if.monitor_mp)::set(null, "uvm_test_top.env.master_agent.mon", "vif", ahb_vif.monitor_mp);
    uvm_config_db #(virtual apb_if.monitor_mp)::set(null, "uvm_test_top.env.slave_agent.mon",  "vif", apb_vif.monitor_mp);
    run_test();
  end
  initial begin #1_000_000; `uvm_fatal("TIMEOUT", "Simulation timeout!") end
endmodule
