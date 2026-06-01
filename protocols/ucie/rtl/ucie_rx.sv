// UCIe RX adapter: receives flits from link, returns credits to TX.
// Registers each incoming flit and pulses credit_return to replenish TX credits.
module ucie_rx #(
  parameter int FLIT_WIDTH = 256
)(
  input  logic                  clk,
  input  logic                  rst_n,
  // Link input from TX
  input  logic [FLIT_WIDTH-1:0] link_data,
  input  logic                  link_valid,
  // Host output
  output logic [FLIT_WIDTH-1:0] flit_out,
  output logic                  flit_out_valid,
  // Credit return to TX (asserted 1 cycle after accepting a flit)
  output logic                  credit_return
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      flit_out       <= '0;
      flit_out_valid <= 1'b0;
      credit_return  <= 1'b0;
    end else begin
      flit_out       <= link_data;
      flit_out_valid <= link_valid;
      // Return credit one cycle after accepting so TX can refill
      credit_return  <= link_valid;
    end
  end

endmodule
