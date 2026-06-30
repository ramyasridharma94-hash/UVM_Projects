// APB slave-side monitor interface
interface apb_if (input logic clk, input logic rst_n);
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  logic [3:0]  pstrb;
  logic [2:0]  pprot;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  clocking monitor_cb @(posedge clk);
    default input #1;
    input psel, penable, pwrite, paddr, pwdata, pstrb, pprot,
          prdata, pready, pslverr;
  endclocking

  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);
endinterface : apb_if
