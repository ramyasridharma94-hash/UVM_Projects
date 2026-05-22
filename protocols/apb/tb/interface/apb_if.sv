interface apb_if #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
)(
  input logic clk,
  input logic rst_n
);

  logic [ADDR_WIDTH-1:0] paddr;
  logic                  psel;
  logic                  penable;
  logic                  pwrite;
  logic [DATA_WIDTH-1:0] pwdata;
  logic [DATA_WIDTH-1:0] prdata;
  logic                  pready;
  logic                  pslverr;

  clocking master_cb @(posedge clk);
    default input #1ns output #1ns;
    output paddr, psel, penable, pwrite, pwdata;
    input  prdata, pready, pslverr;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input paddr, psel, penable, pwrite, pwdata;
    input prdata, pready, pslverr;
  endclocking

  modport master_mp  (clocking master_cb,  input clk, rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, rst_n);

endinterface
