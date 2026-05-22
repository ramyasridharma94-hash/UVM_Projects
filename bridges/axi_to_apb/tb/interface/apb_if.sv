// APB slave-side monitoring interface for bridge project
interface apb_if #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
)(
  input logic clk,
  input logic rst_n
);
  logic [ADDR_WIDTH-1:0] paddr;
  logic                  psel, penable, pwrite;
  logic [DATA_WIDTH-1:0] pwdata, prdata;
  logic                  pready, pslverr;

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input paddr, psel, penable, pwrite, pwdata, prdata, pready, pslverr;
  endclocking

  modport monitor_mp (clocking monitor_cb, input clk, rst_n);
endinterface
