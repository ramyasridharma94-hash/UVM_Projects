// UART TX: 8N1, baud rate configurable via CLK_DIV
module uart_tx #(
  parameter CLK_FREQ  = 50_000_000,
  parameter BAUD_RATE = 115_200
)(
  input  logic       clk,
  input  logic       rst_n,
  input  logic [7:0] tx_data,
  input  logic       tx_valid,
  output logic       tx_ready,
  output logic       tx
);

  localparam CLK_DIV = CLK_FREQ / BAUD_RATE;

  typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_e;
  state_e state;

  logic [$clog2(CLK_DIV)-1:0] clk_cnt;
  logic [2:0]                 bit_idx;
  logic [7:0]                 shift_reg;
  logic                       baud_tick;

  assign baud_tick = (clk_cnt == CLK_DIV-1);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      clk_cnt  <= '0;
      bit_idx  <= '0;
      shift_reg<= '0;
      tx       <= 1'b1;
      tx_ready <= 1'b1;
    end else begin
      case (state)
        IDLE: begin
          tx       <= 1'b1;
          tx_ready <= 1'b1;
          clk_cnt  <= '0;
          if (tx_valid) begin
            shift_reg <= tx_data;
            tx_ready  <= 1'b0;
            state     <= START;
          end
        end
        START: begin
          tx <= 1'b0;
          if (baud_tick) begin
            clk_cnt <= '0;
            bit_idx <= '0;
            state   <= DATA;
          end else clk_cnt <= clk_cnt + 1;
        end
        DATA: begin
          tx <= shift_reg[bit_idx];
          if (baud_tick) begin
            clk_cnt <= '0;
            if (bit_idx == 3'd7) state <= STOP;
            else                 bit_idx <= bit_idx + 1;
          end else clk_cnt <= clk_cnt + 1;
        end
        STOP: begin
          tx <= 1'b1;
          if (baud_tick) begin
            clk_cnt  <= '0;
            tx_ready <= 1'b1;
            state    <= IDLE;
          end else clk_cnt <= clk_cnt + 1;
        end
      endcase
    end
  end

endmodule
