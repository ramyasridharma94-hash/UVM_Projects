// UART RX: 8N1, samples at middle of bit period
module uart_rx #(
  parameter CLK_FREQ  = 50_000_000,
  parameter BAUD_RATE = 115_200
)(
  input  logic       clk,
  input  logic       rst_n,
  input  logic       rx,
  output logic [7:0] rx_data,
  output logic       rx_valid
);

  localparam CLK_DIV      = CLK_FREQ / BAUD_RATE;
  localparam CLK_DIV_HALF = CLK_DIV / 2;

  typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_e;
  state_e state;

  logic [$clog2(CLK_DIV)-1:0] clk_cnt;
  logic [2:0]                 bit_idx;
  logic [7:0]                 shift_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      clk_cnt   <= '0;
      bit_idx   <= '0;
      shift_reg <= '0;
      rx_data   <= '0;
      rx_valid  <= 1'b0;
    end else begin
      rx_valid <= 1'b0;
      case (state)
        IDLE: begin
          if (!rx) begin   // Falling edge = START bit detected
            clk_cnt <= '0;
            state   <= START;
          end
        end
        START: begin
          if (clk_cnt == CLK_DIV_HALF) begin
            clk_cnt <= '0;
            bit_idx <= '0;
            state   <= DATA;
          end else clk_cnt <= clk_cnt + 1;
        end
        DATA: begin
          if (clk_cnt == CLK_DIV-1) begin
            shift_reg <= {rx, shift_reg[7:1]};
            clk_cnt   <= '0;
            if (bit_idx == 3'd7) state <= STOP;
            else                 bit_idx <= bit_idx + 1;
          end else clk_cnt <= clk_cnt + 1;
        end
        STOP: begin
          if (clk_cnt == CLK_DIV-1) begin
            clk_cnt  <= '0;
            rx_data  <= shift_reg;
            rx_valid <= 1'b1;
            state    <= IDLE;
          end else clk_cnt <= clk_cnt + 1;
        end
      endcase
    end
  end

endmodule
