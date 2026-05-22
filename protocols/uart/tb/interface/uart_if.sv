interface uart_if (
  input logic clk,
  input logic rst_n
);

  logic       tx;
  logic       rx;
  logic [7:0] tx_data;
  logic       tx_valid;
  logic       tx_ready;
  logic [7:0] rx_data;
  logic       rx_valid;

  clocking master_cb @(posedge clk);
    default input #1ns output #1ns;
    output tx_data, tx_valid;
    input  tx_ready, tx;
    input  rx_data, rx_valid;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1ns;
    input tx, rx, tx_data, tx_valid, tx_ready, rx_data, rx_valid;
  endclocking

  modport master_mp  (clocking master_cb,  input clk, rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, rst_n);

endinterface
