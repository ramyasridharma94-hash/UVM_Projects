// SPI master interface for SPI-to-I2C bridge project
interface spi_if (
  input logic clk,
  input logic rst_n
);
  logic sclk;
  logic cs_n;
  logic mosi;
  logic miso;

  clocking master_cb @(posedge clk);
    default input #1ns output #1ns;
    output sclk, cs_n, mosi;
    input  miso;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input sclk, cs_n, mosi, miso;
  endclocking

  modport master_mp  (clocking master_cb,  input clk, rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, rst_n);
endinterface
