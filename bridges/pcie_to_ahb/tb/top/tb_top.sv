`timescale 1ns/1ps
import uvm_pkg::*; `include "uvm_macros.svh"
import pcie_pkg::*;
import pcie_tlp_agent_pkg::*;

module tb_top;
  logic clk, rst_n;
  initial clk = 0; always #5 clk = ~clk;
  initial begin rst_n=0; repeat(10) @(negedge clk); rst_n=1; end

  pcie_tlp_if pcie_if (.clk(clk), .rst_n(rst_n));
  ahb_if      ahb_if  (.clk(clk), .rst_n(rst_n));

  pcie_to_ahb_bridge dut (
    .clk(clk), .rst_n(rst_n),
    .req_valid(pcie_if.req_valid), .req_tlp_type(pcie_if.req_tlp_type),
    .req_addr(pcie_if.req_addr),   .req_length(pcie_if.req_length),
    .req_data(pcie_if.req_data),   .req_first_be(pcie_if.req_first_be),
    .req_last_be(pcie_if.req_last_be), .req_tag(pcie_if.req_tag),
    .req_req_id(pcie_if.req_req_id),   .req_ready(pcie_if.req_ready),
    .cpl_valid(pcie_if.cpl_valid), .cpl_data(pcie_if.cpl_data),
    .cpl_tag(pcie_if.cpl_tag),     .cpl_status(pcie_if.cpl_status),
    .hsel(ahb_if.hsel), .haddr(ahb_if.haddr), .htrans(ahb_if.htrans),
    .hwrite(ahb_if.hwrite), .hsize(ahb_if.hsize), .hburst(ahb_if.hburst),
    .hwdata(ahb_if.hwdata), .hrdata(ahb_if.hrdata),
    .hready(ahb_if.hready), .hresp(ahb_if.hresp)
  );

  // AHB slave memory model
  logic [31:0] mem [0:255];
  logic [31:0] hrdata_r;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) hrdata_r <= 0;
    else if (ahb_if.hsel && ahb_if.htrans[1]) begin
      if (ahb_if.hwrite) mem[ahb_if.haddr[9:2]] <= ahb_if.hwdata;
      else               hrdata_r <= mem[ahb_if.haddr[9:2]];
    end
  end
  assign ahb_if.hrdata = hrdata_r;
  assign ahb_if.hready = 1'b1;
  assign ahb_if.hresp  = 2'b00;

  initial begin
    uvm_config_db #(virtual pcie_tlp_if)::set(null,"uvm_test_top.*","pcie_tlp_vif",pcie_if);
    uvm_config_db #(virtual ahb_if)::set(null,"uvm_test_top.*","ahb_vif",ahb_if);
    run_test();
  end
  initial begin $dumpfile("ahb_bridge_tb.vcd"); $dumpvars(0,tb_top); end
  initial begin #20_000ns; `uvm_fatal("TB_TOP","Simulation timeout") end
endmodule
