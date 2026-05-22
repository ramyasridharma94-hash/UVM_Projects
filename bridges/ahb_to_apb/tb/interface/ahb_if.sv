// AHB master interface for AHB-to-APB bridge project
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
  logic                  hready_out; // from bridge
  logic                  hready_in;  // from master
  logic                  hresp;
  logic                  hsel;

  clocking master_cb @(posedge clk);
    default input #1ns output #1ns;
    output haddr, htrans, hwrite, hsize, hburst, hwdata, hsel;
    input  hrdata, hready_out, hresp;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input haddr, htrans, hwrite, hsize, hburst, hwdata;
    input hrdata, hready_out, hresp, hsel;
  endclocking

  modport master_mp  (clocking master_cb,  input clk, rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, rst_n);
endinterface
