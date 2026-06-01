// UCIe TX adapter: credit-based FIFO transmitter
// Buffers host flits and sends to link when credits (granted by RX) are available.
module ucie_tx #(
  parameter int FLIT_WIDTH = 256,
  parameter int FIFO_DEPTH = 8
)(
  input  logic                  clk,
  input  logic                  rst_n,
  // Host interface
  input  logic [FLIT_WIDTH-1:0] flit_in,
  input  logic                  flit_valid,
  output logic                  flit_ready,
  // Credit return from RX (1 pulse = 1 credit)
  input  logic                  credit_return,
  // Link output to RX
  output logic [FLIT_WIDTH-1:0] link_data,
  output logic                  link_valid
);

  localparam int CREDIT_W = $clog2(FIFO_DEPTH + 1); // bits to hold 0..FIFO_DEPTH
  localparam int PTR_W    = $clog2(FIFO_DEPTH);     // bits for FIFO pointers

  logic [FLIT_WIDTH-1:0] fifo [FIFO_DEPTH];
  logic [PTR_W-1:0]      wr_ptr, rd_ptr;
  logic [CREDIT_W-1:0]   fill, credits;

  logic push, pop;

  // Host can push when FIFO has room
  assign flit_ready = (fill < FIFO_DEPTH);
  // TX sends when FIFO is non-empty and has a credit from RX
  assign link_valid = (fill > 0) && (credits > 0);
  assign link_data  = fifo[rd_ptr];

  assign push = flit_valid && flit_ready;
  assign pop  = link_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr  <= '0;
      rd_ptr  <= '0;
      fill    <= '0;
      credits <= CREDIT_W'(FIFO_DEPTH); // RX pre-grants all buffer slots
    end else begin
      // FIFO write
      if (push) begin
        fifo[wr_ptr] <= flit_in;
        wr_ptr       <= (wr_ptr == PTR_W'(FIFO_DEPTH - 1)) ? '0 : wr_ptr + 1;
      end
      // FIFO read
      if (pop)
        rd_ptr <= (rd_ptr == PTR_W'(FIFO_DEPTH - 1)) ? '0 : rd_ptr + 1;

      // Fill tracking
      if (push && !pop)      fill <= fill + 1;
      else if (!push && pop) fill <= fill - 1;

      // Credit tracking: consume on pop, replenish on credit_return from RX
      if (pop && !credit_return)      credits <= credits - 1;
      else if (!pop && credit_return) credits <= credits + 1;
    end
  end

endmodule
