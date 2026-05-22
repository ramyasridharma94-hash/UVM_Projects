interface axi4_if #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32,
  parameter ID_WIDTH   = 4
)(
  input logic clk,
  input logic rst_n
);

  // Write Address Channel
  logic [ID_WIDTH-1:0]     awid;
  logic [ADDR_WIDTH-1:0]   awaddr;
  logic [7:0]              awlen;
  logic [2:0]              awsize;
  logic [1:0]              awburst;
  logic                    awvalid;
  logic                    awready;

  // Write Data Channel
  logic [DATA_WIDTH-1:0]   wdata;
  logic [DATA_WIDTH/8-1:0] wstrb;
  logic                    wlast;
  logic                    wvalid;
  logic                    wready;

  // Write Response Channel
  logic [ID_WIDTH-1:0]     bid;
  logic [1:0]              bresp;
  logic                    bvalid;
  logic                    bready;

  // Read Address Channel
  logic [ID_WIDTH-1:0]     arid;
  logic [ADDR_WIDTH-1:0]   araddr;
  logic [7:0]              arlen;
  logic [2:0]              arsize;
  logic [1:0]              arburst;
  logic                    arvalid;
  logic                    arready;

  // Read Data Channel
  logic [ID_WIDTH-1:0]     rid;
  logic [DATA_WIDTH-1:0]   rdata;
  logic [1:0]              rresp;
  logic                    rlast;
  logic                    rvalid;
  logic                    rready;

  clocking master_cb @(posedge clk);
    default input #1ns output #1ns;
    output awid, awaddr, awlen, awsize, awburst, awvalid;
    input  awready;
    output wdata, wstrb, wlast, wvalid;
    input  wready;
    input  bid, bresp, bvalid;
    output bready;
    output arid, araddr, arlen, arsize, arburst, arvalid;
    input  arready;
    input  rid, rdata, rresp, rlast, rvalid;
    output rready;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input awid, awaddr, awlen, awsize, awburst, awvalid, awready;
    input wdata, wstrb, wlast, wvalid, wready;
    input bid, bresp, bvalid, bready;
    input arid, araddr, arlen, arsize, arburst, arvalid, arready;
    input rid, rdata, rresp, rlast, rvalid, rready;
  endclocking

  modport master_mp  (clocking master_cb,  input clk, rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, rst_n);

endinterface
