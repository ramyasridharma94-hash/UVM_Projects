interface ucie_if (
  input logic clk,
  input logic rst_n
);

  // 256-bit UCIe flit (main band)
  logic [255:0] tx_flit_data;
  logic         tx_flit_valid;
  logic         tx_flit_ready;
  logic [255:0] rx_flit_data;
  logic         rx_flit_valid;

  clocking master_cb @(posedge clk);
    default input #1ns output #1ns;
    output tx_flit_data, tx_flit_valid;
    input  tx_flit_ready;
    input  rx_flit_data, rx_flit_valid;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input tx_flit_data, tx_flit_valid, tx_flit_ready;
    input rx_flit_data, rx_flit_valid;
  endclocking

  modport master_mp  (clocking master_cb,  input clk, rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, rst_n);

endinterface
