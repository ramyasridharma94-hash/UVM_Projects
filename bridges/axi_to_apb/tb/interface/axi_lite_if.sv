// Copy of AXI4-Lite interface for bridge project master port
interface axi_lite_if #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
)(
  input logic clk,
  input logic rst_n
);
  logic [ADDR_WIDTH-1:0]   awaddr;
  logic                    awvalid, awready;
  logic [DATA_WIDTH-1:0]   wdata;
  logic [DATA_WIDTH/8-1:0] wstrb;
  logic                    wvalid, wready;
  logic [1:0]              bresp;
  logic                    bvalid, bready;
  logic [ADDR_WIDTH-1:0]   araddr;
  logic                    arvalid, arready;
  logic [DATA_WIDTH-1:0]   rdata;
  logic [1:0]              rresp;
  logic                    rvalid, rready;

  clocking master_cb @(posedge clk);
    default input #1ns output #1ns;
    output awaddr, awvalid; input  awready;
    output wdata, wstrb, wvalid; input  wready;
    input  bresp, bvalid; output bready;
    output araddr, arvalid; input  arready;
    input  rdata, rresp, rvalid; output rready;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input awaddr, awvalid, awready;
    input wdata, wstrb, wvalid, wready;
    input bresp, bvalid, bready;
    input araddr, arvalid, arready;
    input rdata, rresp, rvalid, rready;
  endclocking

  modport master_mp  (clocking master_cb,  input clk, rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, rst_n);
endinterface
