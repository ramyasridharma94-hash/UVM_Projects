// I2C monitoring interface for SPI-to-I2C bridge project
interface i2c_if (
  input logic clk,
  input logic rst_n
);
  logic scl;
  wire  sda;

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input scl, sda;
  endclocking

  modport monitor_mp (clocking monitor_cb, input clk, rst_n);
endinterface
