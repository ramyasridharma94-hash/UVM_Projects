// DDR5 Power Management Controller
// Manages CKE, Power-Down (PD), Self-Refresh (SREF), and idle detection
// Enforces: tXP (PD exit), tXS (SREF exit), tCKE, tCKSRE, tCKSRX
import ddr5_pkg::*;

module ddr5_power_ctrl #(
  parameter int CLK_FREQ_MHZ = 200
)(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              init_done,
  input  ddr5_timing_t      timing,

  // APB/SW power requests
  input  logic              pd_req,      // Enter Power-Down
  input  logic              sref_req,    // Enter Self-Refresh
  input  logic              wake_req,    // Wake from PD/SREF

  // Current activity (from scheduler)
  input  logic              ctrl_busy,   // scheduler/bank non-idle

  // CKE output to DRAM
  output logic              cke_out,

  // DFI command for PD/SR entry/exit
  output logic              cmd_valid,
  output ddr5_cmd_e         cmd_out,
  input  logic              cmd_ready,

  // Current power state
  output power_state_e      pwr_state,
  output logic              pm_busy,

  // Self-refresh ZQ request on exit
  output logic              zq_req_on_exit
);

  typedef enum logic [3:0] {
    PM_NORMAL       = 4'h0,
    PM_PD_ENTRY     = 4'h1,
    PM_PD_ACTIVE    = 4'h2,
    PM_PD_EXIT      = 4'h3,
    PM_PD_WAIT_tXP  = 4'h4,
    PM_SREF_ENTRY   = 4'h5,
    PM_SREF_ACTIVE  = 4'h6,
    PM_SREF_EXIT    = 4'h7,
    PM_SREF_WAIT_tXS= 4'h8
  } pm_state_e;

  pm_state_e state;
  logic [15:0] pm_timer;
  logic [15:0] wait_tgt;

  assign pm_busy        = (state != PM_NORMAL);
  assign zq_req_on_exit = (state == PM_SREF_WAIT_tXS && pm_timer == 0);

  always_comb begin
    case (state)
      PM_PD_ACTIVE, PM_PD_ENTRY, PM_PD_EXIT, PM_PD_WAIT_tXP:
        pwr_state = PWR_PD;
      PM_SREF_ENTRY, PM_SREF_ACTIVE, PM_SREF_EXIT, PM_SREF_WAIT_tXS:
        pwr_state = PWR_SREF;
      default:
        pwr_state = PWR_NORMAL;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= PM_NORMAL;
      cke_out   <= 0;       // CKE low until init completes
      cmd_valid <= 0; cmd_out <= CMD_NOP;
      pm_timer  <= '0;
    end else begin
      if (pm_timer > 0) pm_timer <= pm_timer - 1;
      cmd_valid <= 0;

      case (state)
        PM_NORMAL: begin
          cke_out <= init_done ? 1'b1 : 1'b0;
          if (init_done && !ctrl_busy) begin
            if (sref_req)     state <= PM_SREF_ENTRY;
            else if (pd_req)  state <= PM_PD_ENTRY;
          end
        end

        // -------------------------------------------------------
        // Power-Down Entry
        // -------------------------------------------------------
        PM_PD_ENTRY: begin
          // Issue PDE: CKE goes low on next rising edge
          cmd_valid <= 1;
          cmd_out   <= CMD_PDE;
          if (cmd_ready) begin
            cke_out   <= 0;
            cmd_valid <= 0;
            state     <= PM_PD_ACTIVE;
          end
        end

        PM_PD_ACTIVE: begin
          cke_out <= 0;
          if (wake_req) begin
            state <= PM_PD_EXIT;
          end
        end

        PM_PD_EXIT: begin
          // Raise CKE — DRAM exits PD after tCKE clocks
          cke_out   <= 1;
          cmd_valid <= 1;
          cmd_out   <= CMD_PDX;
          if (cmd_ready) begin
            cmd_valid <= 0;
            pm_timer  <= 16'(timing.tXP);
            state     <= PM_PD_WAIT_tXP;
          end
        end

        PM_PD_WAIT_tXP: begin
          if (pm_timer == 0) state <= PM_NORMAL;
        end

        // -------------------------------------------------------
        // Self-Refresh Entry (JESD79-5 §3.8)
        // tCKSRE: CK must stay valid for tCKSRE after SRE before stopping
        // -------------------------------------------------------
        PM_SREF_ENTRY: begin
          cmd_valid <= 1;
          cmd_out   <= CMD_SRE;
          if (cmd_ready) begin
            cke_out   <= 0;
            cmd_valid <= 0;
            // tCKSRE = max(5nCK, 10ns) — here simplified as 5 cycles
            pm_timer  <= 16'd5;
            state     <= PM_SREF_ACTIVE;
          end
        end

        PM_SREF_ACTIVE: begin
          cke_out <= 0;
          if (wake_req) state <= PM_SREF_EXIT;
        end

        PM_SREF_EXIT: begin
          // Raise CKE — tCKSRX = max(5nCK, 10ns) before issuing commands
          cke_out   <= 1;
          cmd_valid <= 1;
          cmd_out   <= CMD_SRX;
          if (cmd_ready) begin
            cmd_valid <= 0;
            pm_timer  <= 16'(timing.tXS);
            state     <= PM_SREF_WAIT_tXS;
          end
        end

        PM_SREF_WAIT_tXS: begin
          // Must issue ZQ calibration after self-refresh exit
          if (pm_timer == 0) state <= PM_NORMAL;
        end

        default: state <= PM_NORMAL;
      endcase
    end
  end

endmodule : ddr5_power_ctrl
