// UCIe adapter top: TX FIFO → internal link → RX register (loopback for standalone verification).
// Models credit-based flow control: RX grants FIFO_DEPTH initial credits to TX;
// each flit consumed by RX returns one credit, allowing TX to send the next flit.
module ucie_adapter_top #(
  parameter int FLIT_WIDTH = 256,
  parameter int FIFO_DEPTH = 8
)(
  input  logic                  clk,
  input  logic                  rst_n,
  // TX host interface
  input  logic [FLIT_WIDTH-1:0] tx_flit_data,
  input  logic                  tx_flit_valid,
  output logic                  tx_flit_ready,
  // RX host interface
  output logic [FLIT_WIDTH-1:0] rx_flit_data,
  output logic                  rx_flit_valid
);

  logic [FLIT_WIDTH-1:0] link_data;
  logic                  link_valid;
  logic                  credit_return;

  ucie_tx #(.FLIT_WIDTH(FLIT_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) u_tx (
    .clk          (clk),
    .rst_n        (rst_n),
    .flit_in      (tx_flit_data),
    .flit_valid   (tx_flit_valid),
    .flit_ready   (tx_flit_ready),
    .credit_return(credit_return),
    .link_data    (link_data),
    .link_valid   (link_valid)
  );

  ucie_rx #(.FLIT_WIDTH(FLIT_WIDTH)) u_rx (
    .clk           (clk),
    .rst_n         (rst_n),
    .link_data     (link_data),
    .link_valid    (link_valid),
    .flit_out      (rx_flit_data),
    .flit_out_valid(rx_flit_valid),
    .credit_return (credit_return)
  );

endmodule
