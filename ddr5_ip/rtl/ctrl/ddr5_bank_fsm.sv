// DDR5 Per-Bank FSM — tracks open/closed state, enforces tRCD/tRP/tRAS/tRTP/tWR
import ddr5_pkg::*;

module ddr5_bank_fsm #(
  parameter int ROW_BITS = 17,
  parameter int BANK_IDX = 0    // Flat bank index (BG*4 + BA)
)(
  input  logic              clk,
  input  logic              rst_n,
  input  ddr5_timing_t      timing,
  // Command bus (broadcast from scheduler)
  input  logic              cmd_valid,
  input  ddr5_cmd_e         cmd,
  input  logic [2:0]        cmd_bg,
  input  logic [1:0]        cmd_bank,
  input  logic [ROW_BITS-1:0] cmd_row,
  // State outputs
  output logic              bank_open,
  output logic [ROW_BITS-1:0] open_row,
  output logic              bank_ready,   // Ready to accept next command
  output logic              tRP_met,
  output logic              tRCD_met,
  output logic              tRAS_met
);

  typedef enum logic [2:0] {
    IDLE, ACTIVATING, ACTIVE, PRECHARGING, REFRESHING, AUTO_PRECHARGE
  } bank_state_e;

  bank_state_e state;
  logic [15:0] timer;
  logic [15:0] ras_timer;  // tRAS enforcement
  logic        my_cmd;

  assign my_cmd = cmd_valid && (cmd_bg == 3'(BANK_IDX/4)) && (cmd_bank == 2'(BANK_IDX%4));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE; timer <= 0; ras_timer <= 0;
      bank_open <= 0; open_row <= '0; bank_ready <= 1;
      tRP_met <= 1; tRCD_met <= 0; tRAS_met <= 0;
    end else begin
      if (timer > 0) timer <= timer - 1;
      if (ras_timer > 0) ras_timer <= ras_timer - 1;

      tRP_met  <= (state == IDLE && timer == 0);
      tRCD_met <= (state == ACTIVE);
      tRAS_met <= (state == ACTIVE && ras_timer == 0);

      case (state)
        IDLE: begin
          bank_ready <= 1; bank_open <= 0;
          if (my_cmd && cmd == CMD_ACT) begin
            state     <= ACTIVATING;
            timer     <= 16'(timing.tRCD);
            ras_timer <= 16'(timing.tRAS);
            open_row  <= cmd_row;
            bank_ready<= 0; bank_open <= 0;
          end
        end

        ACTIVATING: begin
          bank_ready <= 0;
          if (timer == 0) begin
            state      <= ACTIVE;
            bank_open  <= 1;
            bank_ready <= 1;
          end
        end

        ACTIVE: begin
          if (my_cmd) begin
            case (cmd)
              CMD_PRE: begin
                if (tRAS_met) begin
                  state     <= PRECHARGING;
                  timer     <= 16'(timing.tRP);
                  bank_open <= 0; bank_ready <= 0;
                end
              end
              CMD_WRA: begin
                // tWR before auto-precharge
                state     <= AUTO_PRECHARGE;
                timer     <= 16'(timing.tWR);
                bank_ready<= 0;
              end
              CMD_RDA: begin
                // tRTP before auto-precharge
                state     <= AUTO_PRECHARGE;
                timer     <= 16'(timing.tRTP);
                bank_ready<= 0;
              end
              default: ;
            endcase
          end
        end

        AUTO_PRECHARGE: begin
          bank_ready <= 0;
          if (timer == 0) begin
            state     <= PRECHARGING;
            timer     <= 16'(timing.tRP);
            bank_open <= 0;
          end
        end

        PRECHARGING: begin
          bank_ready <= 0; bank_open <= 0;
          if (timer == 0) begin state <= IDLE; bank_ready <= 1; end
        end

        REFRESHING: begin
          bank_ready <= 0; bank_open <= 0;
          if (timer == 0) begin state <= IDLE; bank_ready <= 1; end
        end
      endcase

      // Override: global refresh
      if (cmd_valid && (cmd == CMD_REF || cmd == CMD_REFPB)) begin
        state     <= REFRESHING;
        timer     <= 16'(timing.tRFC);
        bank_open <= 0; bank_ready <= 0;
      end
    end
  end

endmodule : ddr5_bank_fsm
