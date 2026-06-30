// PCIe UVM Testbench Top
`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import pcie_pkg::*;
import pcie_agent_pkg::*;

module tb_top;

  // -----------------------------------------------------------------------
  // Clock and reset
  // -----------------------------------------------------------------------
  logic clk, rst_n;
  initial clk = 0;
  always #5 clk = ~clk;   // 100 MHz

  initial begin
    rst_n = 0;
    repeat (10) @(negedge clk);
    rst_n = 1;
  end

  // -----------------------------------------------------------------------
  // Interface instance
  // -----------------------------------------------------------------------
  pcie_if dut_if (.clk(clk), .rst_n(rst_n));

  // -----------------------------------------------------------------------
  // DUT — pcie_top
  // -----------------------------------------------------------------------
  pcie_top #(.MAX_LANES(16), .MAX_GEN(5)) dut (
    .clk                (clk),
    .rst_n              (rst_n),
    // Application
    .app_init_req       (dut_if.app_init_req),
    .app_target_speed   (dut_if.app_target_speed),
    .app_target_width   (dut_if.app_target_width),
    // TLP Request
    .req_valid          (dut_if.req_valid),
    .req_tlp_type       (dut_if.req_tlp_type),
    .req_addr           (dut_if.req_addr),
    .req_length         (dut_if.req_length),
    .req_tc             (dut_if.req_tc),
    .req_attr           (dut_if.req_attr),
    .req_req_id         (dut_if.req_req_id),
    .req_tag            (dut_if.req_tag),
    .req_first_be       (dut_if.req_first_be),
    .req_last_be        (dut_if.req_last_be),
    .req_msg_code       (dut_if.req_msg_code),
    .req_ep             (dut_if.req_ep),
    .req_ecrc_en        (dut_if.req_ecrc_en),
    .req_data_lo        (dut_if.req_data_lo),
    .req_data_hi        (dut_if.req_data_hi),
    .req_ready          (dut_if.req_ready),
    // Posted receive
    .posted_valid       (dut_if.posted_valid),
    .posted_type        (dut_if.posted_type),
    .posted_addr        (dut_if.posted_addr),
    .posted_length      (dut_if.posted_length),
    .posted_data        (dut_if.posted_data),
    .posted_tc          (dut_if.posted_tc),
    .posted_ep          (dut_if.posted_ep),
    // Non-posted receive
    .np_valid           (dut_if.np_valid),
    .np_type            (dut_if.np_type),
    .np_addr            (dut_if.np_addr),
    .np_length          (dut_if.np_length),
    .np_req_id          (dut_if.np_req_id),
    .np_tag             (dut_if.np_tag),
    .np_first_be        (dut_if.np_first_be),
    .np_last_be         (dut_if.np_last_be),
    .np_tc              (dut_if.np_tc),
    // Completion receive
    .cpl_valid          (dut_if.cpl_valid),
    .cpl_type           (dut_if.cpl_type),
    .cpl_status         (dut_if.cpl_status),
    .cpl_req_id         (dut_if.cpl_req_id),
    .cpl_tag            (dut_if.cpl_tag),
    .cpl_byte_cnt       (dut_if.cpl_byte_cnt),
    .cpl_data           (dut_if.cpl_data),
    // Config space
    .cfg_rd_valid       (dut_if.cfg_rd_valid),
    .cfg_wr_valid       (dut_if.cfg_wr_valid),
    .cfg_reg_num        (dut_if.cfg_reg_num),
    .cfg_req_id_out     (dut_if.cfg_req_id_out),
    .cfg_tag_out        (dut_if.cfg_tag_out),
    .cfg_wr_data        (dut_if.cfg_wr_data),
    .cfg_be             (dut_if.cfg_be),
    // Power management
    .pm_enter_l1_req    (dut_if.pm_enter_l1_req),
    .pm_ack             (dut_if.pm_ack),
    // LTSSM / link
    .ltssm_state        (dut_if.ltssm_state),
    .link_up            (dut_if.link_up),
    .negotiated_speed   (dut_if.negotiated_speed),
    .negotiated_width   (dut_if.negotiated_width),
    .loopback_en        (dut_if.loopback_en),
    .link_disable       (dut_if.link_disable),
    .inject_framing_err (dut_if.inject_framing_err),
    // AER
    .aer_error          (dut_if.aer_error),
    .aer_error_valid    (dut_if.aer_error_valid),
    // SERDES
    .tx_elec_idle       (dut_if.tx_elec_idle),
    .rx_elec_idle       (dut_if.rx_elec_idle),
    .tx_valid           (dut_if.tx_valid_phy),
    .tx_data            (dut_if.tx_data_phy),
    .rx_valid           (dut_if.rx_valid_phy),
    .rx_data            (dut_if.rx_data_phy)
  );

  // -----------------------------------------------------------------------
  // UVM kickoff
  // -----------------------------------------------------------------------
  initial begin
    uvm_config_db #(virtual pcie_if)::set(null, "uvm_test_top.*", "pcie_vif", dut_if);
    run_test();
  end

  // -----------------------------------------------------------------------
  // Waveform dump
  // -----------------------------------------------------------------------
  initial begin
    $dumpfile("pcie_tb.vcd");
    $dumpvars(0, tb_top);
  end

  // Simulation timeout
  initial begin
    #50_000ns;
    `uvm_fatal("TB_TOP", "Simulation timeout — check test objectives")
  end

endmodule : tb_top
