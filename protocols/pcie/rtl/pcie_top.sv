// PCIe Top-Level — integrates PHY, DLL, TLP TX/RX
import pcie_pkg::*;

module pcie_top #(
  parameter int MAX_LANES  = 16,
  parameter int MAX_GEN    = 5
)(
  input  logic              clk,
  input  logic              rst_n,
  // Application configuration
  input  logic              app_init_req,
  input  link_speed_e       app_target_speed,
  input  link_width_e       app_target_width,
  // TLP request from application
  input  logic              req_valid,
  input  tlp_type_e         req_tlp_type,
  input  logic [63:0]       req_addr,
  input  logic [9:0]        req_length,
  input  logic [2:0]        req_tc,
  input  logic [1:0]        req_attr,
  input  logic [15:0]       req_req_id,
  input  logic [7:0]        req_tag,
  input  logic [3:0]        req_first_be,
  input  logic [3:0]        req_last_be,
  input  logic [2:0]        req_msg_code,
  input  logic              req_ep,
  input  logic              req_ecrc_en,
  input  logic [63:0]       req_data_lo,
  input  logic [63:0]       req_data_hi,
  output logic              req_ready,
  // Received TLP outputs — posted
  output logic              posted_valid,
  output tlp_type_e         posted_type,
  output logic [63:0]       posted_addr,
  output logic [9:0]        posted_length,
  output logic [63:0]       posted_data,
  output logic [2:0]        posted_tc,
  output logic              posted_ep,
  // Received TLP outputs — non-posted
  output logic              np_valid,
  output tlp_type_e         np_type,
  output logic [63:0]       np_addr,
  output logic [9:0]        np_length,
  output logic [15:0]       np_req_id,
  output logic [7:0]        np_tag,
  output logic [3:0]        np_first_be,
  output logic [3:0]        np_last_be,
  output logic [2:0]        np_tc,
  // Received TLP outputs — completion
  output logic              cpl_valid,
  output tlp_type_e         cpl_type,
  output cpl_status_e       cpl_status,
  output logic [15:0]       cpl_req_id,
  output logic [7:0]        cpl_tag,
  output logic [11:0]       cpl_byte_cnt,
  output logic [63:0]       cpl_data,
  // Config space
  output logic              cfg_rd_valid,
  output logic              cfg_wr_valid,
  output logic [11:0]       cfg_reg_num,
  output logic [15:0]       cfg_req_id_out,
  output logic [7:0]        cfg_tag_out,
  output logic [31:0]       cfg_wr_data,
  output logic [3:0]        cfg_be,
  // Power management
  input  logic              pm_enter_l1_req,
  output logic              pm_ack,
  // LTSSM/Link status
  output ltssm_state_e      ltssm_state,
  output logic              link_up,
  output link_speed_e       negotiated_speed,
  output logic [4:0]        negotiated_width,
  // Error reporting (AER)
  output pcie_error_e       aer_error,
  output logic              aer_error_valid,
  // Loopback / disable controls
  input  logic              loopback_en,
  input  logic              link_disable,
  input  logic              inject_framing_err,
  // SERDES
  output logic [MAX_LANES-1:0] tx_elec_idle,
  input  logic [MAX_LANES-1:0] rx_elec_idle,
  output logic              tx_valid,
  output logic [7:0]        tx_data,
  input  logic              rx_valid,
  input  logic [7:0]        rx_data
);

  // Internal wires
  logic              dl_up;
  // PHY error
  pcie_error_e       phy_error;
  // DLL <-> TLP wires
  logic              tlp_tx_valid, tlp_tx_ready;
  logic [255:0]      tlp_tx_data;
  logic [2:0]        tlp_tx_len;
  logic              tlp_rx_valid, tlp_rx_ready;
  logic [255:0]      tlp_rx_data;
  logic [2:0]        tlp_rx_len;
  logic              dllp_tx_valid, dllp_tx_ready;
  logic [31:0]       dllp_tx_data;
  logic              dllp_rx_valid;
  logic [31:0]       dllp_rx_data;
  // FC credits
  fc_credits_t       fc_p, fc_np, fc_cpl;
  fc_credits_t       rmt_fc_p, rmt_fc_np, rmt_fc_cpl;
  // DLL error
  pcie_error_e       dll_error;
  logic              dll_error_valid;
  // RX error
  pcie_error_e       rx_error;
  logic              rx_error_valid;
  // TLP TX status
  logic              tlp_sent;
  logic [7:0]        tlp_tag_out;
  pcie_error_e       tlp_tx_error;

  // Remote FC (simplified: same as local for TB loopback)
  assign rmt_fc_p   = fc_p;
  assign rmt_fc_np  = fc_np;
  assign rmt_fc_cpl = fc_cpl;
  assign dllp_tx_ready = 1'b1;
  assign dllp_rx_valid = 1'b0;
  assign dllp_rx_data  = '0;

  // AER mux — combine errors from PHY, DLL, RX
  always_comb begin
    if (phy_error != ERR_NONE)       begin aer_error = phy_error;  aer_error_valid = 1; end
    else if (dll_error_valid)        begin aer_error = dll_error;  aer_error_valid = 1; end
    else if (rx_error_valid)         begin aer_error = rx_error;   aer_error_valid = 1; end
    else                             begin aer_error = ERR_NONE;   aer_error_valid = 0; end
  end

  // -----------------------------------------------------------------------
  // Sub-module instantiation
  // -----------------------------------------------------------------------
  pcie_phy #(.MAX_LANES(MAX_LANES), .MAX_GEN(MAX_GEN)) u_phy (
    .clk              (clk),
    .rst_n            (rst_n),
    .app_init_req     (app_init_req),
    .app_target_speed (app_target_speed),
    .app_target_width (app_target_width),
    .ltssm_state      (ltssm_state),
    .dl_up            (dl_up),
    .negotiated_width (negotiated_width),
    .negotiated_speed (negotiated_speed),
    .rx_detected      (),
    .loopback_en      (loopback_en),
    .link_disable     (link_disable),
    .inject_framing_err(inject_framing_err),
    .tx_elec_idle     (tx_elec_idle),
    .rx_elec_idle     (rx_elec_idle),
    .tx_valid         (tx_valid),
    .tx_data          (tx_data),
    .rx_valid         (rx_valid),
    .rx_data          (rx_data),
    .link_up          (link_up),
    .link_in_recovery (),
    .phy_error        (phy_error)
  );

  pcie_dll u_dll (
    .clk              (clk),
    .rst_n            (rst_n),
    .dl_up            (dl_up),
    .tlp_tx_valid     (tlp_tx_valid),
    .tlp_tx_data      (tlp_tx_data),
    .tlp_tx_len_dw    (tlp_tx_len),
    .tlp_tx_ready     (tlp_tx_ready),
    .tlp_rx_valid     (tlp_rx_valid),
    .tlp_rx_data      (tlp_rx_data),
    .tlp_rx_len_dw    (tlp_rx_len),
    .tlp_rx_ready     (tlp_rx_ready),
    .dllp_tx_valid    (dllp_tx_valid),
    .dllp_tx_data     (dllp_tx_data),
    .dllp_tx_ready    (dllp_tx_ready),
    .dllp_rx_valid    (dllp_rx_valid),
    .dllp_rx_data     (dllp_rx_data),
    .fc_posted        (fc_p),
    .fc_non_posted    (fc_np),
    .fc_completion    (fc_cpl),
    .remote_fc_posted (rmt_fc_p),
    .remote_fc_non_posted(rmt_fc_np),
    .remote_fc_completion(rmt_fc_cpl),
    .pm_enter_l1_req  (pm_enter_l1_req),
    .pm_ack           (pm_ack),
    .dll_error        (dll_error),
    .dll_error_valid  (dll_error_valid)
  );

  pcie_tlp_tx u_tlp_tx (
    .clk              (clk),
    .rst_n            (rst_n),
    .req_valid        (req_valid),
    .req_tlp_type     (req_tlp_type),
    .req_addr         (req_addr),
    .req_length       (req_length),
    .req_tc           (req_tc),
    .req_attr         (req_attr),
    .req_req_id       (req_req_id),
    .req_tag          (req_tag),
    .req_first_be     (req_first_be),
    .req_last_be      (req_last_be),
    .req_msg_code     (req_msg_code),
    .req_ep           (req_ep),
    .req_ecrc_en      (req_ecrc_en),
    .req_data_lo      (req_data_lo),
    .req_data_hi      (req_data_hi),
    .req_ready        (req_ready),
    .tlp_valid        (tlp_tx_valid),
    .tlp_data         (tlp_tx_data),
    .tlp_len_dw       (tlp_tx_len),
    .tlp_ready        (tlp_tx_ready),
    .fc_posted        (rmt_fc_p),
    .fc_non_posted    (rmt_fc_np),
    .fc_completion    (rmt_fc_cpl),
    .tlp_sent         (tlp_sent),
    .tlp_tag_out      (tlp_tag_out),
    .tlp_error        (tlp_tx_error)
  );

  pcie_tlp_rx u_tlp_rx (
    .clk              (clk),
    .rst_n            (rst_n),
    .tlp_valid        (tlp_rx_valid),
    .tlp_data         (tlp_rx_data),
    .tlp_len_dw       (tlp_rx_len),
    .tlp_ready        (tlp_rx_ready),
    .posted_valid     (posted_valid),
    .posted_type      (posted_type),
    .posted_addr      (posted_addr),
    .posted_length    (posted_length),
    .posted_data      (posted_data),
    .posted_tc        (posted_tc),
    .posted_ep        (posted_ep),
    .np_valid         (np_valid),
    .np_type          (np_type),
    .np_addr          (np_addr),
    .np_length        (np_length),
    .np_req_id        (np_req_id),
    .np_tag           (np_tag),
    .np_first_be      (np_first_be),
    .np_last_be       (np_last_be),
    .np_tc            (np_tc),
    .cpl_valid        (cpl_valid),
    .cpl_type         (cpl_type),
    .cpl_status       (cpl_status),
    .cpl_req_id       (cpl_req_id),
    .cpl_tag          (cpl_tag),
    .cpl_byte_cnt     (cpl_byte_cnt),
    .cpl_data         (cpl_data),
    .rx_error         (rx_error),
    .rx_error_valid   (rx_error_valid),
    .cfg_rd_valid     (cfg_rd_valid),
    .cfg_wr_valid     (cfg_wr_valid),
    .cfg_reg_num      (cfg_reg_num),
    .cfg_req_id       (cfg_req_id_out),
    .cfg_tag          (cfg_tag_out),
    .cfg_wr_data      (cfg_wr_data),
    .cfg_be           (cfg_be)
  );

  assign tlp_rx_ready = 1'b1;

endmodule : pcie_top
