// DDR5 ZQ Calibration Controller
// Manages ZQCAL_Start → ZQCAL_Latch sequence, periodic ZQ operations
import ddr5_pkg::*;

module ddr5_zq_ctrl (
  input  logic              clk,
  input  logic              rst_n,
  input  ddr5_timing_t      timing,
  input  logic              init_done,
  input  logic              zq_req,       // software-triggered ZQ
  // Command interface
  output logic              cmd_valid,
  output ddr5_cmd_e         cmd_out,
  input  logic              cmd_ready,
  // Status
  output logic              zq_active,
  output logic              zq_done,
  output logic [15:0]       zq_count
);

  typedef enum logic [1:0] { ZQ_IDLE, ZQ_LATCH, ZQ_WAIT, ZQ_DONE } zq_state_e;
  zq_state_e state;
  logic [15:0] timer;
  logic [15:0] interval_cnt;
  localparam int ZQ_INTERVAL = 30_000; // periodic ZQ every ~300ms (simplified)

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ZQ_IDLE; timer <= 0; interval_cnt <= 0;
      cmd_valid <= 0; cmd_out <= CMD_NOP;
      zq_active <= 0; zq_done <= 0; zq_count <= 0;
    end else begin
      zq_done   <= 0;
      cmd_valid <= 0;
      if (timer > 0) timer <= timer - 1;

      // Periodic trigger
      if (init_done) begin
        interval_cnt <= interval_cnt + 1;
        if (interval_cnt >= ZQ_INTERVAL) interval_cnt <= 0;
      end

      case (state)
        ZQ_IDLE: begin
          zq_active <= 0;
          if ((zq_req || interval_cnt == 0) && init_done) begin
            state     <= ZQ_LATCH;
            cmd_valid <= 1;
            cmd_out   <= CMD_ZQCAL;
            zq_active <= 1;
            timer     <= 16'(timing.tZQoper);
          end
        end
        ZQ_LATCH: begin
          if (cmd_ready) begin cmd_valid <= 0; state <= ZQ_WAIT; end
        end
        ZQ_WAIT: begin
          if (timer == 0) begin
            cmd_valid <= 1; cmd_out <= CMD_ZQLAT;
            state     <= ZQ_DONE;
          end
        end
        ZQ_DONE: begin
          if (cmd_ready) begin
            cmd_valid <= 0; zq_done <= 1; zq_active <= 0;
            zq_count  <= zq_count + 1;
            state     <= ZQ_IDLE;
          end
        end
      endcase
    end
  end

endmodule : ddr5_zq_ctrl
