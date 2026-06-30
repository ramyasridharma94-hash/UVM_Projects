interface axi4_if (input logic clk, input logic rst_n);
  // Write Address
  logic        awvalid, awready;
  logic [63:0] awaddr; logic [7:0] awlen, awid; logic [2:0] awsize, awprot;
  logic [1:0]  awburst; logic [3:0] awcache;
  // Write Data
  logic        wvalid, wready, wlast;
  logic [127:0]wdata; logic [15:0] wstrb;
  // Write Response
  logic        bvalid, bready;
  logic [1:0]  bresp; logic [7:0] bid;
  // Read Address
  logic        arvalid, arready;
  logic [63:0] araddr; logic [7:0] arlen, arid; logic [2:0] arsize, arprot;
  logic [1:0]  arburst; logic [3:0] arcache;
  // Read Data
  logic        rvalid, rready, rlast;
  logic [127:0]rdata; logic [1:0] rresp; logic [7:0] rid;

  clocking monitor_cb @(posedge clk);
    default input #1;
    input awvalid,awready,awaddr,awlen,awsize,awburst,awid,awprot,awcache;
    input wvalid,wready,wdata,wstrb,wlast;
    input bvalid,bready,bresp,bid;
    input arvalid,arready,araddr,arlen,arsize,arburst,arid,arprot,arcache;
    input rvalid,rready,rdata,rresp,rid,rlast;
  endclocking
  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);
endinterface
