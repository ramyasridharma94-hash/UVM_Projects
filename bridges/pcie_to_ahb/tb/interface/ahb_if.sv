interface ahb_if (input logic clk, input logic rst_n);
  logic        hsel;
  logic [31:0] haddr;
  logic [1:0]  htrans;
  logic        hwrite;
  logic [2:0]  hsize;
  logic [2:0]  hburst;
  logic [31:0] hwdata;
  logic [31:0] hrdata;
  logic        hready;
  logic [1:0]  hresp;

  clocking monitor_cb @(posedge clk);
    default input #1;
    input hsel, haddr, htrans, hwrite, hsize, hburst, hwdata,
          hrdata, hready, hresp;
  endclocking
  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);
endinterface
