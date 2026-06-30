`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import pcie_pkg::*;
import pcie_tlp_agent_pkg::*;

module tb_top;
  logic clk, rst_n;
  initial clk = 0;
  always #5 clk = ~clk;
  initial begin rst_n = 0; repeat(10) @(negedge clk); rst_n = 1; end

  pcie_tlp_if pcie_if (.clk(clk), .rst_n(rst_n));
  apb_if      apb_if  (.clk(clk), .rst_n(rst_n));

  // DUT
  pcie_to_apb_bridge dut (
    .clk        (clk),        .rst_n       (rst_n),
    .req_valid  (pcie_if.req_valid),
    .req_tlp_type(pcie_if.req_tlp_type),
    .req_addr   (pcie_if.req_addr),
    .req_length (pcie_if.req_length),
    .req_data   (pcie_if.req_data),
    .req_tag    (pcie_if.req_tag),
    .req_req_id (pcie_if.req_req_id),
    .req_first_be(pcie_if.req_first_be),
    .req_ready  (pcie_if.req_ready),
    .cpl_valid  (pcie_if.cpl_valid),
    .cpl_data   (pcie_if.cpl_data),
    .cpl_tag    (pcie_if.cpl_tag),
    .cpl_status (pcie_if.cpl_status),
    .psel       (apb_if.psel),   .penable (apb_if.penable),
    .pwrite     (apb_if.pwrite), .paddr   (apb_if.paddr),
    .pwdata     (apb_if.pwdata), .pstrb   (apb_if.pstrb),
    .pprot      (apb_if.pprot),
    .prdata     (apb_if.prdata), .pready  (apb_if.pready),
    .pslverr    (apb_if.pslverr)
  );

  // APB slave memory model (256×32b)
  logic [31:0] mem [0:255];
  logic        pslverr_r;
  logic [31:0] prdata_r;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin pslverr_r <= 0; prdata_r <= 0; end
    else if (apb_if.psel && apb_if.penable) begin
      pslverr_r <= (apb_if.pwdata == 32'hDEAD_0E12); // inject slverr trigger
      if (apb_if.pwrite && !pslverr_r)
        mem[apb_if.paddr[9:2]] <= apb_if.pwdata;
      prdata_r <= mem[apb_if.paddr[9:2]];
    end
  end
  assign apb_if.prdata  = prdata_r;
  assign apb_if.pready  = 1'b1;
  assign apb_if.pslverr = pslverr_r;

  initial begin
    uvm_config_db #(virtual pcie_tlp_if)::set(null,"uvm_test_top.*","pcie_tlp_vif", pcie_if);
    uvm_config_db #(virtual apb_if)::set(null,"uvm_test_top.*","apb_vif", apb_if);
    run_test();
  end

  initial begin $dumpfile("apb_bridge_tb.vcd"); $dumpvars(0, tb_top); end
  initial begin #20_000ns; `uvm_fatal("TB_TOP","Simulation timeout") end
endmodule
