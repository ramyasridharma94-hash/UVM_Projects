// PCIe Physical Layer — LTSSM, lane management, speed negotiation (Gen1-Gen5)
import pcie_pkg::*;

module pcie_phy #(
  parameter int MAX_LANES     = 16,
  parameter int MAX_GEN       = 5,
  parameter int DETECT_TMOUT  = 12,   // ms (simplified to cycles)
  parameter int POLLING_TMOUT = 24
)(
  input  logic              clk,
  input  logic              rst_n,
  // Application interface
  input  logic              app_init_req,     // request link initialization
  input  link_speed_e       app_target_speed,
  input  link_width_e       app_target_width,
  output ltssm_state_e      ltssm_state,
  output logic              dl_up,            // Data Link Layer Up
  output logic [4:0]        negotiated_width,
  output link_speed_e       negotiated_speed,
  // Receiver detect
  output logic              rx_detected,
  // Loopback / disable
  input  logic              loopback_en,
  input  logic              link_disable,
  // Error injection
  input  logic              inject_framing_err,
  // SERDES (simplified)
  output logic [MAX_LANES-1:0] tx_elec_idle,
  input  logic [MAX_LANES-1:0] rx_elec_idle,
  output logic              tx_valid,
  output logic [7:0]        tx_data,
  input  logic              rx_valid,
  input  logic [7:0]        rx_data,
  // Status
  output logic              link_up,
  output logic              link_in_recovery,
  output pcie_error_e       phy_error
);

  ltssm_state_e state, next_state;
  logic [15:0]  timer;
  logic [4:0]   lane_count;
  logic [2:0]   speed_gen;
  logic         detect_done;
  logic         ts1_seen, ts2_seen;
  logic [7:0]   ts_cnt;
  logic         speed_change_req;

  // LTSSM state register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= LTSSM_DETECT_QUIET;
    else        state <= next_state;
  end

  // Timer
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)               timer <= '0;
    else if (state != next_state) timer <= '0;
    else                      timer <= timer + 1;
  end

  // TS1/TS2 ordered set counter (simplified)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ts1_seen <= 0; ts2_seen <= 0; ts_cnt <= 0;
    end else if (rx_valid) begin
      // Simplified: detect TS ordered sets by data pattern
      if (rx_data == 8'hBC) begin ts1_seen <= 1; ts_cnt <= ts_cnt + 1; end
      if (rx_data == 8'hFD) begin ts2_seen <= 1; ts_cnt <= ts_cnt + 1; end
    end else if (state != next_state) begin
      ts1_seen <= 0; ts2_seen <= 0; ts_cnt <= 0;
    end
  end

  // LTSSM next-state logic
  always_comb begin
    next_state = state;
    case (state)
      LTSSM_DETECT_QUIET: begin
        if (app_init_req)               next_state = LTSSM_DETECT_ACTIVE;
        if (link_disable)               next_state = LTSSM_DISABLED;
      end
      LTSSM_DETECT_ACTIVE: begin
        if (!rx_elec_idle[0])           next_state = LTSSM_POLLING_ACTIVE;
        else if (timer > DETECT_TMOUT)  next_state = LTSSM_DETECT_QUIET;
      end
      LTSSM_POLLING_ACTIVE: begin
        if (ts1_seen && ts_cnt >= 8'd8) next_state = LTSSM_POLLING_CFG;
        else if (timer > POLLING_TMOUT) next_state = LTSSM_DETECT_QUIET;
        if (loopback_en)                next_state = LTSSM_LOOPBACK_ENTRY;
      end
      LTSSM_POLLING_CFG: begin
        if (ts2_seen && ts_cnt >= 8'd8) next_state = LTSSM_CFG_LNKWD_STR;
        else if (timer > POLLING_TMOUT) next_state = LTSSM_DETECT_QUIET;
      end
      LTSSM_CFG_LNKWD_STR:  next_state = LTSSM_CFG_LNKWD_ACPT;
      LTSSM_CFG_LNKWD_ACPT: next_state = LTSSM_CFG_LNKNUM_WAIT;
      LTSSM_CFG_LNKNUM_WAIT:next_state = LTSSM_CFG_LNKNUM_ACPT;
      LTSSM_CFG_LNKNUM_ACPT:next_state = LTSSM_CFG_COMPLETE;
      LTSSM_CFG_COMPLETE: begin
        if (timer > 4)                  next_state = LTSSM_CFG_IDLE;
      end
      LTSSM_CFG_IDLE: begin
        next_state = LTSSM_L0;
        if (speed_change_req)           next_state = LTSSM_RECOVERY_SPEED;
      end
      LTSSM_L0: begin
        if (link_disable)               next_state = LTSSM_DISABLED;
        if (inject_framing_err)         next_state = LTSSM_RECOVERY_RCVR;
        if (rx_elec_idle[0])            next_state = LTSSM_L0s_RX;
        if (speed_change_req)           next_state = LTSSM_RECOVERY_SPEED;
      end
      LTSSM_L0s_TX: begin
        if (timer > 8)                  next_state = LTSSM_L0;
      end
      LTSSM_L0s_RX: begin
        if (!rx_elec_idle[0])           next_state = LTSSM_L0;
        if (timer > 16)                 next_state = LTSSM_RECOVERY_RCVR;
      end
      LTSSM_L1: begin
        if (!rx_elec_idle[0])           next_state = LTSSM_RECOVERY_RCVR;
      end
      LTSSM_L2: begin
        // Only wake via PME
        if (!rx_elec_idle[0])           next_state = LTSSM_DETECT_QUIET;
      end
      LTSSM_RECOVERY_RCVR: begin
        if (ts1_seen)                   next_state = LTSSM_RECOVERY_RCVR_CFG;
        if (timer > 24)                 next_state = LTSSM_DETECT_QUIET;
      end
      LTSSM_RECOVERY_SPEED: begin
        if (timer > 8)                  next_state = LTSSM_RECOVERY_RCVR;
      end
      LTSSM_RECOVERY_RCVR_CFG: begin
        if (ts2_seen)                   next_state = LTSSM_RECOVERY_IDLE;
      end
      LTSSM_RECOVERY_IDLE: begin
        if (timer > 2)                  next_state = LTSSM_L0;
      end
      LTSSM_HOT_RESET: begin
        if (timer > 2)                  next_state = LTSSM_DETECT_QUIET;
      end
      LTSSM_LOOPBACK_ENTRY:  next_state = LTSSM_LOOPBACK_ACTIVE;
      LTSSM_LOOPBACK_ACTIVE: begin
        if (!loopback_en)               next_state = LTSSM_LOOPBACK_EXIT;
      end
      LTSSM_LOOPBACK_EXIT:   next_state = LTSSM_DETECT_QUIET;
      LTSSM_DISABLED: begin
        if (!link_disable)              next_state = LTSSM_DETECT_QUIET;
      end
      default:                          next_state = LTSSM_DETECT_QUIET;
    endcase
  end

  // Link speed negotiation
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      speed_gen        <= 3'd1;
      lane_count       <= 5'd1;
      speed_change_req <= 0;
    end else if (state == LTSSM_CFG_COMPLETE) begin
      // Negotiate to minimum of target and peer capability (simplified)
      speed_gen  <= (app_target_speed > GEN1) ? 3'(int'(app_target_speed)) : 3'd1;
      lane_count <= 5'(int'(app_target_width));
    end else if (state == LTSSM_L0 && app_target_speed != link_speed_e'(speed_gen)) begin
      speed_change_req <= 1;
    end else if (state == LTSSM_RECOVERY_SPEED) begin
      speed_gen        <= 3'(int'(app_target_speed));
      speed_change_req <= 0;
    end
  end

  // Output assignments
  assign ltssm_state      = state;
  assign dl_up            = (state == LTSSM_L0);
  assign link_up          = (state == LTSSM_L0);
  assign link_in_recovery = (state inside {LTSSM_RECOVERY_RCVR, LTSSM_RECOVERY_SPEED,
                                            LTSSM_RECOVERY_RCVR_CFG, LTSSM_RECOVERY_IDLE});
  assign negotiated_width = lane_count;
  assign negotiated_speed = link_speed_e'(speed_gen);
  assign rx_detected      = (state != LTSSM_DETECT_QUIET) && (state != LTSSM_DISABLED);

  // TX electrical idle in non-L0 states
  assign tx_elec_idle = (state inside {LTSSM_L1, LTSSM_L2, LTSSM_L0s_TX,
                                        LTSSM_DETECT_QUIET}) ? '1 : '0;

  // TX data: send TS1 during Polling, TS2 during Config, SKP in L0
  always_comb begin
    tx_valid = 0; tx_data = 8'h00;
    case (state)
      LTSSM_POLLING_ACTIVE: begin tx_valid = 1; tx_data = 8'hBC; end // TS1 COM
      LTSSM_POLLING_CFG:    begin tx_valid = 1; tx_data = 8'hFD; end // TS2 COM
      LTSSM_CFG_LNKWD_STR, LTSSM_CFG_LNKWD_ACPT,
      LTSSM_CFG_LNKNUM_WAIT, LTSSM_CFG_LNKNUM_ACPT: begin
        tx_valid = 1; tx_data = 8'hFD;
      end
      LTSSM_L0: begin tx_valid = 1; tx_data = 8'h1C; end // SKP
      LTSSM_RECOVERY_RCVR:     begin tx_valid = 1; tx_data = 8'hBC; end
      LTSSM_RECOVERY_RCVR_CFG: begin tx_valid = 1; tx_data = 8'hFD; end
      default: begin tx_valid = 0; tx_data = 8'h00; end
    endcase
  end

  // AER error reporting
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)               phy_error <= ERR_NONE;
    else if (inject_framing_err) phy_error <= ERR_BAD_TLP;
    else if (state == LTSSM_L0 && rx_valid && rx_data == 8'hFE)
                              phy_error <= ERR_BAD_DLLP;
    else                      phy_error <= ERR_NONE;
  end

endmodule : pcie_phy
