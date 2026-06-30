// DDR5 Refresh Controller — Normal, FGR(2x/4x), Per-Bank, Same-Bank refresh
import ddr5_pkg::*;

module ddr5_refresh_ctrl #(
  parameter int NUM_BK = 32
)(
  input  logic              clk,
  input  logic              rst_n,
  input  ddr5_timing_t      timing,
  input  refresh_mode_e     ref_mode,
  input  logic              init_done,
  // Refresh request/grant to command scheduler
  output logic              ref_req,
  output ddr5_cmd_e         ref_cmd,
  output logic [2:0]        ref_bg,
  output logic [1:0]        ref_bank,
  input  logic              ref_grant,
  // Alert: refresh timeout
  output logic              ref_timeout,
  output logic [7:0]        ref_debt        // pending refresh count
);

  logic [15:0] ref_timer;
  logic [15:0] ref_interval;
  logic [4:0]  pbr_bank;       // Per-Bank Refresh bank pointer
  int unsigned debt;

  always_comb begin
    case (ref_mode)
      REF_FGR_2X: ref_interval = 16'(timing.tREFI / 2);
      REF_FGR_4X: ref_interval = 16'(timing.tREFI / 4);
      default:    ref_interval = 16'(timing.tREFI);
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ref_timer <= 0; debt <= 0; pbr_bank <= 0;
      ref_req <= 0; ref_cmd <= CMD_NOP;
      ref_bg <= '0; ref_bank <= '0;
      ref_timeout <= 0; ref_debt <= 0;
    end else if (init_done) begin
      ref_timeout <= 0;

      // Tick timer
      if (ref_timer >= ref_interval - 1) begin
        ref_timer <= 0;
        debt      <= debt + 1;
        if (debt >= 8) ref_timeout <= 1;  // spec: max 8 deferred refreshes
      end else ref_timer <= ref_timer + 1;

      // Issue refresh when debt > 0
      if (debt > 0 && !ref_req) begin
        ref_req <= 1;
        case (ref_mode)
          REF_PBR: begin
            ref_cmd  <= CMD_REFPB;
            ref_bg   <= pbr_bank[4:2];
            ref_bank <= pbr_bank[1:0];
            pbr_bank <= (pbr_bank == 5'(NUM_BK-1)) ? 0 : pbr_bank + 1;
          end
          REF_SBR: begin
            ref_cmd  <= CMD_REFSB;
            ref_bg   <= pbr_bank[4:2];
            ref_bank <= pbr_bank[1:0];
          end
          default: begin
            ref_cmd  <= CMD_REF;
            ref_bg   <= '0; ref_bank <= '0;
          end
        endcase
      end

      if (ref_req && ref_grant) begin
        ref_req <= 0;
        debt    <= debt - 1;
      end

      ref_debt <= 8'(debt);
    end
  end

endmodule : ddr5_refresh_ctrl
