`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import axi_lite_agent_pkg::*;
import ahb_slv_agent_pkg::*;
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

  axi_lite_if #(.DATA_WIDTH(32), .ADDR_WIDTH(32)) axil_if(.clk(clk), .rst_n(rst_n));
  ahb_if       #(.DATA_WIDTH(32), .ADDR_WIDTH(32)) ahb_vif(.clk(clk), .rst_n(rst_n));

  // AHB memory model
  logic [31:0] ahb_mem [0:15];
  logic [31:0] lat_addr; logic lat_write;
  always_ff @(posedge clk) begin
    if (ahb_vif.hready && (ahb_vif.htrans == 2'b10 || ahb_vif.htrans == 2'b11)) begin
      lat_addr  <= ahb_vif.haddr;
      lat_write <= ahb_vif.hwrite;
    end
    if (lat_write && ahb_vif.hready)
      ahb_mem[(lat_addr>>2)&15] <= ahb_vif.hwdata;
  end
  assign ahb_vif.hrdata = ahb_mem[(ahb_vif.haddr>>2)&15];
  assign ahb_vif.hready = 1'b1;
  assign ahb_vif.hresp  = 1'b0;

  axi_to_ahb_bridge dut (
    .aclk    (clk),      .aresetn (rst_n),
    .s_awaddr(axil_if.awaddr),  .s_awvalid(axil_if.awvalid), .s_awready(axil_if.awready),
    .s_wdata (axil_if.wdata),   .s_wstrb  (axil_if.wstrb),
    .s_wvalid(axil_if.wvalid),  .s_wready (axil_if.wready),
    .s_bresp (axil_if.bresp),   .s_bvalid (axil_if.bvalid),  .s_bready (axil_if.bready),
    .s_araddr(axil_if.araddr),  .s_arvalid(axil_if.arvalid), .s_arready(axil_if.arready),
    .s_rdata (axil_if.rdata),   .s_rresp  (axil_if.rresp),
    .s_rvalid(axil_if.rvalid),  .s_rready (axil_if.rready),
    .m_haddr (ahb_vif.haddr),   .m_htrans (ahb_vif.htrans),
    .m_hwrite(ahb_vif.hwrite),  .m_hsize  (ahb_vif.hsize),
    .m_hburst(ahb_vif.hburst),  .m_hwdata (ahb_vif.hwdata),
    .m_hrdata(ahb_vif.hrdata),  .m_hready (ahb_vif.hready),
    .m_hresp (ahb_vif.hresp)
  );

  initial begin
    uvm_config_db #(virtual axi_lite_if.master_mp)::set(null, "uvm_test_top.env.master_agent.drv", "vif", axil_if.master_mp);
    uvm_config_db #(virtual axi_lite_if.monitor_mp)::set(null, "uvm_test_top.env.master_agent.mon", "vif", axil_if.monitor_mp);
    uvm_config_db #(virtual ahb_if.monitor_mp)::set(null,      "uvm_test_top.env.slave_agent.mon",  "vif", ahb_vif.monitor_mp);
    run_test();
  end
  initial begin #1_000_000; `uvm_fatal("TIMEOUT", "Simulation timeout!") end
endmodule
