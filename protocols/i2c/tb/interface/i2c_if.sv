interface i2c_if (
  input logic clk,
  input logic rst_n
);

  logic scl;
  wire  sda;   // bidirectional — use tri-state

  logic scl_drv;
  logic sda_drv;
  logic sda_oe;

  // Master drives SCL, SDA via enable
  assign scl = scl_drv;
  assign sda = sda_oe ? sda_drv : 1'bz;

  clocking master_cb @(posedge clk);
    default input #1ns output #1ns;
    output scl_drv, sda_drv, sda_oe;
    input  sda;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input scl, sda;
  endclocking

  modport master_mp  (clocking master_cb,  input clk, rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, rst_n);

endinterface
