// PCIe Verification Interface — connects TB to DUT pcie_top
import pcie_pkg::*;

interface pcie_if (input logic clk, input logic rst_n);

  // -----------------------------------------------------------------------
  // Application → DUT (request)
  // -----------------------------------------------------------------------
  logic              req_valid;
  tlp_type_e         req_tlp_type;
  logic [63:0]       req_addr;
  logic [9:0]        req_length;
  logic [2:0]        req_tc;
  logic [1:0]        req_attr;
  logic [15:0]       req_req_id;
  logic [7:0]        req_tag;
  logic [3:0]        req_first_be;
  logic [3:0]        req_last_be;
  logic [2:0]        req_msg_code;
  logic              req_ep;
  logic              req_ecrc_en;
  logic [63:0]       req_data_lo;
  logic [63:0]       req_data_hi;
  logic              req_ready;     // DUT → App: backpressure

  // -----------------------------------------------------------------------
  // DUT → Application (posted receive)
  // -----------------------------------------------------------------------
  logic              posted_valid;
  tlp_type_e         posted_type;
  logic [63:0]       posted_addr;
  logic [9:0]        posted_length;
  logic [63:0]       posted_data;
  logic [2:0]        posted_tc;
  logic              posted_ep;

  // -----------------------------------------------------------------------
  // DUT → Application (non-posted receive)
  // -----------------------------------------------------------------------
  logic              np_valid;
  tlp_type_e         np_type;
  logic [63:0]       np_addr;
  logic [9:0]        np_length;
  logic [15:0]       np_req_id;
  logic [7:0]        np_tag;
  logic [3:0]        np_first_be;
  logic [3:0]        np_last_be;
  logic [2:0]        np_tc;

  // -----------------------------------------------------------------------
  // DUT → Application (completion receive)
  // -----------------------------------------------------------------------
  logic              cpl_valid;
  tlp_type_e         cpl_type;
  cpl_status_e       cpl_status;
  logic [15:0]       cpl_req_id;
  logic [7:0]        cpl_tag;
  logic [11:0]       cpl_byte_cnt;
  logic [63:0]       cpl_data;

  // -----------------------------------------------------------------------
  // Config space
  // -----------------------------------------------------------------------
  logic              cfg_rd_valid;
  logic              cfg_wr_valid;
  logic [11:0]       cfg_reg_num;
  logic [15:0]       cfg_req_id_out;
  logic [7:0]        cfg_tag_out;
  logic [31:0]       cfg_wr_data;
  logic [3:0]        cfg_be;

  // -----------------------------------------------------------------------
  // Power management
  // -----------------------------------------------------------------------
  logic              pm_enter_l1_req;
  logic              pm_ack;

  // -----------------------------------------------------------------------
  // Link / LTSSM control
  // -----------------------------------------------------------------------
  logic              app_init_req;
  link_speed_e       app_target_speed;
  link_width_e       app_target_width;
  ltssm_state_e      ltssm_state;
  logic              link_up;
  link_speed_e       negotiated_speed;
  logic [4:0]        negotiated_width;
  logic              loopback_en;
  logic              link_disable;
  logic              inject_framing_err;

  // -----------------------------------------------------------------------
  // AER
  // -----------------------------------------------------------------------
  pcie_error_e       aer_error;
  logic              aer_error_valid;

  // -----------------------------------------------------------------------
  // SERDES (simplified)
  // -----------------------------------------------------------------------
  logic [15:0]       tx_elec_idle;
  logic [15:0]       rx_elec_idle;
  logic              tx_valid_phy;
  logic [7:0]        tx_data_phy;
  logic              rx_valid_phy;
  logic [7:0]        rx_data_phy;

  // -----------------------------------------------------------------------
  // Clocking blocks
  // -----------------------------------------------------------------------
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output req_valid, req_tlp_type, req_addr, req_length, req_tc, req_attr;
    output req_req_id, req_tag, req_first_be, req_last_be, req_msg_code;
    output req_ep, req_ecrc_en, req_data_lo, req_data_hi;
    output pm_enter_l1_req;
    output app_init_req, app_target_speed, app_target_width;
    output loopback_en, link_disable, inject_framing_err;
    output rx_elec_idle, rx_valid_phy, rx_data_phy;
    input  req_ready, posted_valid, np_valid, cpl_valid;
    input  posted_type, posted_addr, posted_length, posted_data;
    input  np_type, np_addr, np_length, np_req_id, np_tag, np_tc;
    input  cpl_type, cpl_status, cpl_req_id, cpl_tag, cpl_byte_cnt, cpl_data;
    input  cfg_rd_valid, cfg_wr_valid, cfg_reg_num, cfg_wr_data, cfg_be;
    input  pm_ack, link_up, ltssm_state, negotiated_speed, negotiated_width;
    input  aer_error, aer_error_valid;
    input  tx_elec_idle, tx_valid_phy, tx_data_phy;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1;
    input  req_valid, req_tlp_type, req_addr, req_length, req_tc, req_attr;
    input  req_req_id, req_tag, req_first_be, req_last_be, req_msg_code;
    input  req_ep, req_ecrc_en, req_data_lo, req_data_hi;
    input  req_ready;
    input  posted_valid, posted_type, posted_addr, posted_length, posted_data;
    input  posted_tc, posted_ep;
    input  np_valid, np_type, np_addr, np_length, np_req_id, np_tag;
    input  np_first_be, np_last_be, np_tc;
    input  cpl_valid, cpl_type, cpl_status, cpl_req_id, cpl_tag;
    input  cpl_byte_cnt, cpl_data;
    input  cfg_rd_valid, cfg_wr_valid, cfg_reg_num, cfg_wr_data, cfg_be;
    input  pm_enter_l1_req, pm_ack;
    input  app_init_req, app_target_speed, app_target_width;
    input  ltssm_state, link_up, negotiated_speed, negotiated_width;
    input  loopback_en, link_disable, inject_framing_err;
    input  aer_error, aer_error_valid;
    input  tx_elec_idle, tx_valid_phy, tx_data_phy;
    input  rx_elec_idle, rx_valid_phy, rx_data_phy;
  endclocking

  modport driver_mp  (clocking driver_cb,  input clk, input rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);

  // -----------------------------------------------------------------------
  // Assertions
  // -----------------------------------------------------------------------
  // TLP request must be stable until accepted
  property p_req_stable;
    @(posedge clk) disable iff (!rst_n)
    (req_valid && !req_ready) |=> $stable({req_tlp_type, req_addr, req_length, req_tag});
  endproperty
  assert property (p_req_stable)
    else $error("PCIe: req signals changed while req_valid=1 and req_ready=0");

  // Completion must carry a valid tag
  property p_cpl_valid_tag;
    @(posedge clk) disable iff (!rst_n)
    cpl_valid |-> (cpl_tag !== 8'hXX);
  endproperty
  assert property (p_cpl_valid_tag)
    else $warning("PCIe: cpl_valid with undefined tag");

  // Link must be up before any TLP is accepted
  property p_tlp_needs_link_up;
    @(posedge clk) disable iff (!rst_n)
    (req_valid && req_ready) |-> link_up;
  endproperty
  assert property (p_tlp_needs_link_up)
    else $error("PCIe: TLP accepted while link is not up");

endinterface : pcie_if
