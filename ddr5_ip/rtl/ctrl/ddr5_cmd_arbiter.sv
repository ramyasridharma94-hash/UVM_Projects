// DDR5 Command Arbiter — priority-based arbitration across command sources
// Priority (highest→lowest): INIT > POWER_MGMT > REFRESH > ZQ > HOST
// Generates final DFI command stream to the PHY
import ddr5_pkg::*;

module ddr5_cmd_arbiter (
  input  logic              clk,
  input  logic              rst_n,

  // Init FSM commands (highest priority, only active at startup)
  input  logic              init_cmd_valid,
  input  ddr5_cmd_e         init_cmd,
  input  logic [13:0]       init_cmd_addr,
  input  logic              init_cke,
  input  logic              init_cs_n,
  input  logic              init_reset_n,
  output logic              init_cmd_ready,

  // Power Management commands
  input  logic              pm_cmd_valid,
  input  ddr5_cmd_e         pm_cmd,
  output logic              pm_cmd_ready,
  input  logic              pm_cke,
  input  logic              pm_busy,

  // Refresh commands
  input  logic              ref_cmd_valid,
  input  ddr5_cmd_e         ref_cmd,
  input  logic [2:0]        ref_bg,
  input  logic [1:0]        ref_bank,
  output logic              ref_grant,

  // ZQ commands
  input  logic              zq_cmd_valid,
  input  ddr5_cmd_e         zq_cmd,
  output logic              zq_cmd_ready,

  // Mode Register commands
  input  logic              mr_cmd_valid,
  input  ddr5_cmd_e         mr_cmd,
  input  logic [13:0]       mr_cmd_addr,
  output logic              mr_cmd_ready,

  // Host commands (from scheduler)
  input  logic              host_cmd_valid,
  input  ddr5_cmd_e         host_cmd,
  input  logic [13:0]       host_cmd_addr,
  input  logic [2:0]        host_bg,
  input  logic [1:0]        host_bank,
  input  logic [16:0]       host_row,
  input  logic [9:0]        host_col,
  output logic              host_cmd_ready,

  // Init done signal
  input  logic              init_done,

  // Final DFI output
  output logic              dfi_cs_n,
  output logic              dfi_cke,
  output logic              dfi_reset_n,
  output logic [13:0]       dfi_address,
  output logic [2:0]        dfi_bg,
  output logic [1:0]        dfi_bank,
  output ddr5_cmd_e         dfi_cmd,
  output logic              dfi_cmd_valid,
  input  logic              dfi_cmd_ready
);

  // -----------------------------------------------------------------------
  // Arbitration — strictly prioritised, one command per cycle
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    ARB_INIT, ARB_PM, ARB_REF, ARB_ZQ, ARB_MR, ARB_HOST, ARB_NOP
  } arb_winner_e;

  arb_winner_e winner;

  // Pre-emption rules:
  // - During init: only init commands pass
  // - After init: PM > REF > ZQ > MR > HOST
  always_comb begin
    init_cmd_ready = 0; pm_cmd_ready   = 0; ref_grant    = 0;
    zq_cmd_ready   = 0; mr_cmd_ready   = 0; host_cmd_ready = 0;
    winner = ARB_NOP;

    if (!init_done) begin
      // Init phase — only init FSM drives the bus
      winner         = ARB_INIT;
      init_cmd_ready = dfi_cmd_ready;
    end else if (pm_cmd_valid && !ref_cmd_valid) begin
      winner       = ARB_PM;
      pm_cmd_ready = dfi_cmd_ready;
    end else if (ref_cmd_valid && !pm_busy) begin
      winner    = ARB_REF;
      ref_grant = dfi_cmd_ready;
    end else if (zq_cmd_valid && !ref_cmd_valid && !pm_busy) begin
      winner        = ARB_ZQ;
      zq_cmd_ready  = dfi_cmd_ready;
    end else if (mr_cmd_valid && !ref_cmd_valid && !pm_busy) begin
      winner       = ARB_MR;
      mr_cmd_ready = dfi_cmd_ready;
    end else if (host_cmd_valid && !ref_cmd_valid && !pm_busy && !zq_cmd_valid && !mr_cmd_valid) begin
      winner         = ARB_HOST;
      host_cmd_ready = dfi_cmd_ready;
    end
  end

  // -----------------------------------------------------------------------
  // DFI command mux
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dfi_cs_n     <= 1;  dfi_cke  <= 0; dfi_reset_n <= 0;
      dfi_address  <= '0; dfi_bg   <= '0; dfi_bank <= '0;
      dfi_cmd      <= CMD_NOP; dfi_cmd_valid <= 0;
    end else begin
      dfi_cmd_valid <= 0;
      case (winner)
        ARB_INIT: begin
          dfi_cs_n    <= init_cs_n;
          dfi_cke     <= init_cke;
          dfi_reset_n <= init_reset_n;
          dfi_address <= init_cmd_addr;
          dfi_cmd     <= init_cmd;
          dfi_bg      <= '0; dfi_bank <= '0;
          dfi_cmd_valid <= init_cmd_valid;
        end
        ARB_PM: begin
          dfi_cs_n    <= 0;
          dfi_cke     <= pm_cke;
          dfi_reset_n <= 1;
          dfi_address <= 14'h0;
          dfi_cmd     <= pm_cmd;
          dfi_bg      <= '0; dfi_bank <= '0;
          dfi_cmd_valid <= pm_cmd_valid;
        end
        ARB_REF: begin
          dfi_cs_n    <= 0; dfi_cke <= 1; dfi_reset_n <= 1;
          dfi_address <= 14'h0001;
          dfi_cmd     <= ref_cmd;
          dfi_bg      <= ref_bg; dfi_bank <= ref_bank;
          dfi_cmd_valid <= ref_cmd_valid;
        end
        ARB_ZQ: begin
          dfi_cs_n    <= 0; dfi_cke <= 1; dfi_reset_n <= 1;
          dfi_address <= 14'h0100;
          dfi_cmd     <= zq_cmd;
          dfi_bg      <= '0; dfi_bank <= '0;
          dfi_cmd_valid <= zq_cmd_valid;
        end
        ARB_MR: begin
          dfi_cs_n    <= 0; dfi_cke <= 1; dfi_reset_n <= 1;
          dfi_address <= mr_cmd_addr;
          dfi_cmd     <= mr_cmd;
          dfi_bg      <= '0; dfi_bank <= '0;
          dfi_cmd_valid <= mr_cmd_valid;
        end
        ARB_HOST: begin
          dfi_cs_n    <= 0; dfi_cke <= 1; dfi_reset_n <= 1;
          dfi_address <= host_cmd_addr;
          dfi_cmd     <= host_cmd;
          dfi_bg      <= host_bg; dfi_bank <= host_bank;
          dfi_cmd_valid <= host_cmd_valid;
        end
        default: begin
          dfi_cs_n <= 1; dfi_cke <= 1; dfi_reset_n <= 1;
          dfi_address <= '0; dfi_cmd <= CMD_NOP;
          dfi_cmd_valid <= 0;
        end
      endcase
    end
  end

endmodule : ddr5_cmd_arbiter
