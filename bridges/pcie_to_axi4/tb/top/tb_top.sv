`timescale 1ns/1ps
import uvm_pkg::*; `include "uvm_macros.svh"
import pcie_pkg::*;
import pcie_tlp_agent_pkg::*;

module tb_top;
  logic clk, rst_n;
  initial clk=0; always #5 clk=~clk;
  initial begin rst_n=0; repeat(10) @(negedge clk); rst_n=1; end

  pcie_tlp_if pcie_if (.clk(clk), .rst_n(rst_n));
  axi4_if     axi4_if (.clk(clk), .rst_n(rst_n));

  pcie_to_axi4_bridge dut (
    .clk(clk), .rst_n(rst_n),
    .req_valid(pcie_if.req_valid),     .req_tlp_type(pcie_if.req_tlp_type),
    .req_addr(pcie_if.req_addr),       .req_length(pcie_if.req_length),
    .req_tc(pcie_if.req_tc),           .req_attr(pcie_if.req_attr),
    .req_req_id(pcie_if.req_req_id),   .req_tag(pcie_if.req_tag),
    .req_first_be(pcie_if.req_first_be),.req_last_be(pcie_if.req_last_be),
    .req_ep(pcie_if.req_ep),           .req_data_lo(pcie_if.req_data_lo),
    .req_data_hi(pcie_if.req_data_hi), .req_ready(pcie_if.req_ready),
    .cpl_valid(pcie_if.cpl_valid),     .cpl_data(pcie_if.cpl_data),
    .cpl_tag(pcie_if.cpl_tag),         .cpl_status(pcie_if.cpl_status),
    // AXI4
    .awvalid(axi4_if.awvalid), .awready(axi4_if.awready),
    .awaddr(axi4_if.awaddr),   .awlen(axi4_if.awlen),   .awsize(axi4_if.awsize),
    .awburst(axi4_if.awburst), .awid(axi4_if.awid),     .awprot(axi4_if.awprot),
    .awcache(axi4_if.awcache),
    .wvalid(axi4_if.wvalid),   .wready(axi4_if.wready), .wdata(axi4_if.wdata),
    .wstrb(axi4_if.wstrb),     .wlast(axi4_if.wlast),
    .bvalid(axi4_if.bvalid),   .bready(axi4_if.bready), .bresp(axi4_if.bresp),
    .bid(axi4_if.bid),
    .arvalid(axi4_if.arvalid), .arready(axi4_if.arready),
    .araddr(axi4_if.araddr),   .arlen(axi4_if.arlen),   .arsize(axi4_if.arsize),
    .arburst(axi4_if.arburst), .arid(axi4_if.arid),     .arprot(axi4_if.arprot),
    .arcache(axi4_if.arcache),
    .rvalid(axi4_if.rvalid),   .rready(axi4_if.rready), .rdata(axi4_if.rdata),
    .rresp(axi4_if.rresp),     .rid(axi4_if.rid),        .rlast(axi4_if.rlast)
  );

  // AXI4 slave model — 256×128b memory, always-ready
  logic [127:0] mem [0:255];
  logic [127:0] rdata_r;
  logic         bvalid_r, rvalid_r, rlast_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin bvalid_r<=0; rvalid_r<=0; rlast_r<=0; rdata_r<=0; end
    else begin
      bvalid_r <= 0; rvalid_r <= 0; rlast_r <= 0;
      if (axi4_if.awvalid && axi4_if.awready) begin // accept AW immediately
        // write handled in W phase below
      end
      if (axi4_if.wvalid && axi4_if.wready) begin
        mem[axi4_if.awaddr[9:4]] <= axi4_if.wdata;
        if (axi4_if.wlast) bvalid_r <= 1;
      end
      if (axi4_if.arvalid && axi4_if.arready) begin
        rdata_r  <= mem[axi4_if.araddr[9:4]];
        rvalid_r <= 1; rlast_r <= 1;
      end
    end
  end
  assign axi4_if.awready = 1'b1;
  assign axi4_if.wready  = 1'b1;
  assign axi4_if.bvalid  = bvalid_r;
  assign axi4_if.bresp   = 2'b00;
  assign axi4_if.bid     = 8'h0;
  assign axi4_if.arready = 1'b1;
  assign axi4_if.rvalid  = rvalid_r;
  assign axi4_if.rdata   = rdata_r;
  assign axi4_if.rresp   = 2'b00;
  assign axi4_if.rid     = 8'h0;
  assign axi4_if.rlast   = rlast_r;

  initial begin
    uvm_config_db #(virtual pcie_tlp_if)::set(null,"uvm_test_top.*","pcie_tlp_vif",pcie_if);
    uvm_config_db #(virtual axi4_if)::set(null,"uvm_test_top.*","axi4_vif",axi4_if);
    run_test();
  end
  initial begin $dumpfile("axi4_bridge_tb.vcd"); $dumpvars(0,tb_top); end
  initial begin #20_000ns; `uvm_fatal("TB_TOP","Simulation timeout") end
endmodule
