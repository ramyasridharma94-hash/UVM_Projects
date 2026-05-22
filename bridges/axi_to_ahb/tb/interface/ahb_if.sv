// AHB slave-side monitoring interface for bridge project
interface ahb_if #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
)(
  input logic clk,
  input logic rst_n
);
  logic [ADDR_WIDTH-1:0] haddr;
  logic [1:0]            htrans;
  logic                  hwrite;
  logic [2:0]            hsize;
  logic [2:0]            hburst;
  logic [DATA_WIDTH-1:0] hwdata;
  logic [DATA_WIDTH-1:0] hrdata;
  logic                  hready;
  logic                  hresp;

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input haddr, htrans, hwrite, hsize, hburst, hwdata, hrdata, hready, hresp;
  endclocking

  modport monitor_mp (clocking monitor_cb, input clk, rst_n);
endinterface
