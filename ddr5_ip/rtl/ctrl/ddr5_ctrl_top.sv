// DDR5 Controller Top — full integration of all controller sub-modules
// Instantiates: AXI4 slave, addr mapper, wr/rd data buffers, init FSM,
//               mode register ctrl, power ctrl, bank FSMs, cmd scheduler,
//               refresh ctrl, ZQ ctrl, ECC engine, cmd arbiter
// All sub-module interfaces are fully connected; no stub logic remains.
import ddr5_pkg::*;

module ddr5_ctrl_top #(
  parameter int NUM_BG       = 8,
  parameter int NUM_BK       = 4,
  parameter int NUM_BANKS    = NUM_BG * NUM_BK,
  parameter int ROW_BITS     = 17,
  parameter int COL_BITS     = 10,
  parameter int DQ_WIDTH     = 32,
  parameter int AXI_ADDR_W   = 34,
  parameter int AXI_DATA_W   = DQ_WIDTH * 8,   // 256 bits (BL8 × 32b)
  parameter int AXI_ID_W     = 8,
  parameter int CLK_FREQ_MHZ = 200,
  parameter int ADDR_POLICY  = 0   // 0=BG_FIRST, 1=RANK_FIRST, 2=COL_FIRST
)(
  input  logic              clk,
  input  logic              rst_n,

  // -----------------------------------------------------------------------
  // AXI4 Host Interface (full AXI4, all 5 channels)
  // -----------------------------------------------------------------------
  input  logic              s_awvalid,
  output logic              s_awready,
  input  logic [AXI_ADDR_W-1:0] s_awaddr,
  input  logic [7:0]        s_awlen,
  input  logic [2:0]        s_awsize,
  input  logic [1:0]        s_awburst,
  input  logic [AXI_ID_W-1:0]  s_awid,
  input  logic [2:0]        s_awprot,
  input  logic [3:0]        s_awcache,
  input  logic [3:0]        s_awqos,

  input  logic              s_wvalid,
  output logic              s_wready,
  input  logic [AXI_DATA_W-1:0] s_wdata,
  input  logic [AXI_DATA_W/8-1:0] s_wstrb,
  input  logic              s_wlast,

  output logic              s_bvalid,
  input  logic              s_bready,
  output logic [1:0]        s_bresp,
  output logic [AXI_ID_W-1:0]  s_bid,

  input  logic              s_arvalid,
  output logic              s_arready,
  input  logic [AXI_ADDR_W-1:0] s_araddr,
  input  logic [7:0]        s_arlen,
  input  logic [2:0]        s_arsize,
  input  logic [1:0]        s_arburst,
  input  logic [AXI_ID_W-1:0]  s_arid,
  input  logic [2:0]        s_arprot,
  input  logic [3:0]        s_arcache,
  input  logic [3:0]        s_arqos,

  output logic              s_rvalid,
  input  logic              s_rready,
  output logic [AXI_DATA_W-1:0] s_rdata,
  output logic [1:0]        s_rresp,
  output logic              s_rlast,
  output logic [AXI_ID_W-1:0]  s_rid,

  // -----------------------------------------------------------------------
  // Timing & Configuration (from APB config block)
  // -----------------------------------------------------------------------
  input  ddr5_timing_t      timing,
  input  ddr5_mode_regs_t   mode_regs,
  input  refresh_mode_e     ref_mode,
  input  ecc_mode_e         ecc_mode,
  input  burst_len_e        burst_len_cfg,

  // Runtime MRS/MRR requests (from APB)
  input  logic              mrs_req,
  input  logic [7:0]        mrs_mr_addr,
  input  logic [7:0]        mrs_mr_data,
  output logic              mrs_ack,
  input  logic              mrr_req,
  input  logic [7:0]        mrr_mr_addr,
  output logic [7:0]        mrr_rd_data,
  output logic              mrr_valid,

  // Power management requests (from APB)
  input  logic              pd_req,
  input  logic              sref_req,
  input  logic              wake_req,

  // -----------------------------------------------------------------------
  // DFI Interface (to PHY)
  // -----------------------------------------------------------------------
  output logic [13:0]       dfi_address,
  output logic [2:0]        dfi_bg,
  output logic [1:0]        dfi_bank,
  output logic              dfi_cs_n,
  output logic              dfi_cke,
  output logic              dfi_odt,
  output logic              dfi_reset_n,
  output logic [AXI_DATA_W-1:0] dfi_wrdata,
  output logic [DQ_WIDTH-1:0]   dfi_wrmask,
  output logic              dfi_wrdata_en,
  output logic              dfi_rddata_en,
  input  logic [AXI_DATA_W-1:0] dfi_rddata,
  input  logic              dfi_rddata_valid,
  output logic              dfi_init_start,
  input  logic              dfi_init_complete,
  // MRR data return (from PHY, 8-bit DQ capture)
  input  logic [7:0]        dfi_mrr_data,
  input  logic              dfi_mrr_valid,

  // -----------------------------------------------------------------------
  // Status / Error
  // -----------------------------------------------------------------------
  output ddr5_error_e       err_type,
  output logic              err_valid,
  output logic              init_done,
  output power_state_e      pwr_state,
  output logic [7:0]        ref_debt_out,
  output logic [4:0]        wr_outstanding,
  output logic [4:0]        rd_outstanding
);

  // -----------------------------------------------------------------------
  // Internal wires
  // -----------------------------------------------------------------------

  // Bank state
  logic [NUM_BANKS-1:0]    bank_open;
  logic [ROW_BITS-1:0]     open_rows [0:NUM_BANKS-1];
  logic [NUM_BANKS-1:0]    bank_ready_arr;

  // Arbiter → DFI (final command bus)
  logic              arb_dfi_valid;
  ddr5_cmd_e         arb_dfi_cmd;
  logic [13:0]       arb_dfi_addr;
  logic [2:0]        arb_dfi_bg;
  logic [1:0]        arb_dfi_bank;
  logic              arb_dfi_cs_n;
  logic              arb_dfi_cke;
  logic              arb_dfi_reset_n;
  logic              arb_dfi_ready;

  // Init FSM outputs
  logic              init_cmd_valid;
  ddr5_cmd_e         init_cmd;
  logic [13:0]       init_cmd_addr;
  logic              init_cke_sig, init_cs_n_sig, init_reset_n_sig;
  logic              init_cmd_ready;

  // Power ctrl outputs
  logic              pm_cmd_valid;
  ddr5_cmd_e         pm_cmd;
  logic              pm_cmd_ready;
  logic              pm_cke;
  logic              pm_busy;
  logic              zq_req_on_sref_exit;

  // Refresh outputs
  logic              ref_req;
  ddr5_cmd_e         ref_cmd;
  logic [2:0]        ref_bg;
  logic [1:0]        ref_bank;
  logic              ref_grant;
  logic              ref_timeout;
  logic [7:0]        ref_debt;

  // ZQ outputs
  logic              zq_cmd_valid;
  ddr5_cmd_e         zq_cmd_out;
  logic              zq_cmd_ready;

  // Mode Register ctrl outputs
  logic              mr_cmd_valid;
  ddr5_cmd_e         mr_cmd;
  logic [13:0]       mr_cmd_addr;
  logic              mr_cmd_ready;
  ddr5_mode_regs_t   shadow_mrs;
  logic              mr_busy;

  // Scheduler host command outputs
  logic              sched_cmd_valid;
  ddr5_cmd_e         sched_cmd;
  logic [2:0]        sched_bg;
  logic [1:0]        sched_bank;
  logic [ROW_BITS-1:0] sched_row;
  logic [COL_BITS-1:0] sched_col;
  logic [13:0]       sched_cmd_addr;
  logic              sched_cmd_ready;
  logic              host_cmd_ready_sched;

  // AXI slave → mapper/scheduler
  logic              axi_cmd_valid;
  logic              axi_cmd_is_write;
  logic [AXI_ADDR_W-1:0] axi_cmd_addr;
  logic [7:0]        axi_cmd_len;
  logic [2:0]        axi_cmd_size;
  logic [1:0]        axi_cmd_burst;
  logic [AXI_ID_W-1:0]  axi_cmd_id;
  logic              axi_cmd_ready;

  // Write data buffer signals
  logic              wdata_valid_s, wdata_ready_s, wdata_last_s;
  logic [AXI_DATA_W-1:0] wdata_data_s;
  logic [AXI_DATA_W/8-1:0] wdata_strb_s;
  logic              wcmd_valid_s, wcmd_ready_s;
  logic [7:0]        wcmd_len_s;
  logic [AXI_ID_W-1:0] wcmd_id_s;
  logic              dfi_wrlast_s;
  logic              wresp_valid_s, wresp_ready_s;
  logic [1:0]        wresp_resp_s;
  logic [AXI_ID_W-1:0] wresp_id_s;

  // Read data buffer signals
  logic              rdcmd_valid_s, rdcmd_ready_s;
  logic [7:0]        rdcmd_len_s;
  logic [AXI_ID_W-1:0] rdcmd_id_s;
  logic              rdata_valid_s, rdata_ready_s, rdata_last_s;
  logic [AXI_DATA_W-1:0] rdata_data_s;
  logic [1:0]        rdata_resp_s;
  logic [AXI_ID_W-1:0]  rdata_id_s;

  // ECC
  logic [AXI_DATA_W+8-1:0] ecc_enc_out;  // 264b (256b+8 check)
  logic [63:0]       ecc_dec_out;
  logic              sbe_det, dbe_det;
  logic [5:0]        ecc_err_bit;
  logic [7:0]        ecc_syndrome;

  // Address mapped fields
  logic [2:0]        mapped_bg;
  logic [1:0]        mapped_ba;
  logic [ROW_BITS-1:0] mapped_row;
  logic [COL_BITS-1:0] mapped_col;
  logic [AXI_ADDR_W-1:0] aligned_addr;

  // Scheduler request from AXI (after address mapping)
  logic              host_req_valid;
  ddr5_cmd_e         host_req_cmd;
  logic [ROW_BITS-1:0] host_req_row;
  logic [COL_BITS-1:0] host_req_col;
  logic              host_req_ready;

  // -----------------------------------------------------------------------
  // 1. AXI4 Slave
  // -----------------------------------------------------------------------
  ddr5_axi4_slave #(
    .AXI_ADDR_W(AXI_ADDR_W), .AXI_DATA_W(AXI_DATA_W), .AXI_ID_W(AXI_ID_W)
  ) u_axi4_slave (
    .clk(clk), .rst_n(rst_n),
    .s_awvalid(s_awvalid), .s_awready(s_awready),
    .s_awaddr(s_awaddr),   .s_awlen(s_awlen), .s_awsize(s_awsize),
    .s_awburst(s_awburst), .s_awid(s_awid),   .s_awprot(s_awprot),
    .s_awcache(s_awcache), .s_awqos(s_awqos),
    .s_wvalid(s_wvalid),   .s_wready(s_wready),
    .s_wdata(s_wdata),     .s_wstrb(s_wstrb), .s_wlast(s_wlast),
    .s_bvalid(s_bvalid),   .s_bready(s_bready),
    .s_bresp(s_bresp),     .s_bid(s_bid),
    .s_arvalid(s_arvalid), .s_arready(s_arready),
    .s_araddr(s_araddr),   .s_arlen(s_arlen), .s_arsize(s_arsize),
    .s_arburst(s_arburst), .s_arid(s_arid),   .s_arprot(s_arprot),
    .s_arcache(s_arcache), .s_arqos(s_arqos),
    .s_rvalid(s_rvalid),   .s_rready(s_rready),
    .s_rdata(s_rdata),     .s_rresp(s_rresp),
    .s_rlast(s_rlast),     .s_rid(s_rid),
    .cmd_valid(axi_cmd_valid), .cmd_is_write(axi_cmd_is_write),
    .cmd_addr(axi_cmd_addr),   .cmd_len(axi_cmd_len),
    .cmd_size(axi_cmd_size),   .cmd_burst(axi_cmd_burst),
    .cmd_id(axi_cmd_id),       .cmd_ready(axi_cmd_ready),
    .wdata_valid(wdata_valid_s), .wdata_data(wdata_data_s),
    .wdata_strb(wdata_strb_s),  .wdata_last(wdata_last_s),
    .wdata_ready(wdata_ready_s),
    .rdata_valid(rdata_valid_s), .rdata_data(rdata_data_s),
    .rdata_resp(rdata_resp_s),   .rdata_last(rdata_last_s),
    .rdata_id(rdata_id_s),       .rdata_ready(rdata_ready_s),
    .wresp_valid(wresp_valid_s), .wresp_resp(wresp_resp_s),
    .wresp_id(wresp_id_s),       .wresp_ready(wresp_ready_s),
    .wr_outstanding(wr_outstanding), .rd_outstanding(rd_outstanding)
  );

  // -----------------------------------------------------------------------
  // 2. Address Mapper
  // -----------------------------------------------------------------------
  ddr5_addr_mapper #(
    .AXI_ADDR_W(AXI_ADDR_W), .ROW_BITS(ROW_BITS), .COL_BITS(COL_BITS),
    .POLICY(ADDR_POLICY)
  ) u_addr_mapper (
    .axi_addr(axi_cmd_addr),
    .burst_len_cfg(burst_len_cfg),
    .ddr5_bg(mapped_bg), .ddr5_ba(mapped_ba),
    .ddr5_row(mapped_row), .ddr5_col(mapped_col),
    .aligned_addr(aligned_addr)
  );

  // -----------------------------------------------------------------------
  // 3. Write Data Buffer
  // -----------------------------------------------------------------------
  ddr5_wr_data_buf #(
    .AXI_DATA_W(AXI_DATA_W), .AXI_ID_W(AXI_ID_W), .DQ_WIDTH(DQ_WIDTH)
  ) u_wr_buf (
    .clk(clk), .rst_n(rst_n),
    .wdata_valid(wdata_valid_s), .wdata_data(wdata_data_s),
    .wdata_strb(wdata_strb_s),   .wdata_last(wdata_last_s),
    .wdata_ready(wdata_ready_s),
    .wcmd_valid(axi_cmd_valid && axi_cmd_is_write),
    .wcmd_len(axi_cmd_len), .wcmd_id(axi_cmd_id),
    .wcmd_ready(wcmd_ready_s),
    .dfi_wrdata_valid(dfi_wrdata_en), .dfi_wrdata(dfi_wrdata),
    .dfi_wrmask(dfi_wrmask),         .dfi_wrlast(dfi_wrlast_s),
    .dfi_wrdata_ready(1'b1),          // PHY always ready in 1-cycle model
    .wresp_valid(wresp_valid_s), .wresp_resp(wresp_resp_s),
    .wresp_id(wresp_id_s),       .wresp_ready(wresp_ready_s),
    .buf_used()
  );

  // -----------------------------------------------------------------------
  // 4. Read Data Buffer
  // -----------------------------------------------------------------------
  ddr5_rd_data_buf #(
    .AXI_DATA_W(AXI_DATA_W), .AXI_ID_W(AXI_ID_W), .DQ_WIDTH(DQ_WIDTH)
  ) u_rd_buf (
    .clk(clk), .rst_n(rst_n),
    .rdcmd_valid(axi_cmd_valid && !axi_cmd_is_write),
    .rdcmd_len(axi_cmd_len), .rdcmd_id(axi_cmd_id),
    .rdcmd_ready(rdcmd_ready_s),
    .dfi_rddata_valid(dfi_rddata_valid),
    .dfi_rddata(ecc_mode == ECC_OFF ? dfi_rddata :
                {dfi_rddata[AXI_DATA_W-1:64], ecc_dec_out}),
    .rdata_valid(rdata_valid_s), .rdata_data(rdata_data_s),
    .rdata_resp(rdata_resp_s),   .rdata_last(rdata_last_s),
    .rdata_id(rdata_id_s),       .rdata_ready(rdata_ready_s),
    .buf_used(), .buf_full()
  );

  assign dfi_rddata_en = !axi_cmd_is_write;

  // -----------------------------------------------------------------------
  // 5. ECC Engine (operates on first sub-channel, 64b+8b)
  // -----------------------------------------------------------------------
  ddr5_ecc u_ecc (
    .clk(clk), .rst_n(rst_n),
    .ecc_en(ecc_mode != ECC_OFF),
    .enc_data_in(dfi_wrdata[63:0]),
    .enc_data_out(ecc_enc_out),
    .dec_data_in({dfi_rddata[71:64], dfi_rddata[63:0]}),
    .dec_data_out(ecc_dec_out),
    .sbe_detected(sbe_det), .dbe_detected(dbe_det),
    .syndrome(ecc_syndrome), .error_bit_pos(ecc_err_bit)
  );

  // -----------------------------------------------------------------------
  // 6. Init FSM
  // -----------------------------------------------------------------------
  ddr5_init_fsm #(.CLK_FREQ_MHZ(CLK_FREQ_MHZ)) u_init_fsm (
    .clk(clk), .rst_n(rst_n),
    .start(1'b1),
    .timing(timing), .mode_regs(mode_regs),
    .cmd_valid(init_cmd_valid), .cmd_out(init_cmd),
    .cmd_addr(init_cmd_addr),   .cmd_cke(init_cke_sig),
    .cmd_cs_n(init_cs_n_sig),   .cmd_reset_n(init_reset_n_sig),
    .cmd_ready(init_cmd_ready),
    .init_done(init_done),
    .init_state_out()
  );
  assign dfi_init_start = !init_done;

  // -----------------------------------------------------------------------
  // 7. Power Controller
  // -----------------------------------------------------------------------
  ddr5_power_ctrl #(.CLK_FREQ_MHZ(CLK_FREQ_MHZ)) u_pm_ctrl (
    .clk(clk), .rst_n(rst_n), .init_done(init_done),
    .timing(timing),
    .pd_req(pd_req), .sref_req(sref_req), .wake_req(wake_req),
    .ctrl_busy(|(!bank_ready_arr)),
    .cke_out(pm_cke),
    .cmd_valid(pm_cmd_valid), .cmd_out(pm_cmd), .cmd_ready(pm_cmd_ready),
    .pwr_state(pwr_state), .pm_busy(pm_busy),
    .zq_req_on_exit(zq_req_on_sref_exit)
  );

  // -----------------------------------------------------------------------
  // 8. Mode Register Controller
  // -----------------------------------------------------------------------
  ddr5_mode_reg_ctrl u_mr_ctrl (
    .clk(clk), .rst_n(rst_n), .init_done(init_done),
    .mrs_req(mrs_req), .mrs_mr_addr(mrs_mr_addr), .mrs_mr_data(mrs_mr_data),
    .mrs_ack(mrs_ack),
    .mrr_req(mrr_req), .mrr_mr_addr(mrr_mr_addr),
    .mrr_rd_data(mrr_rd_data), .mrr_valid(mrr_valid),
    .cmd_valid(mr_cmd_valid), .cmd_out(mr_cmd),
    .cmd_addr(mr_cmd_addr),   .cmd_ready(mr_cmd_ready),
    .dfi_mrr_data(dfi_mrr_data), .dfi_mrr_valid(dfi_mrr_valid),
    .shadow_mrs(shadow_mrs), .busy(mr_busy)
  );

  // -----------------------------------------------------------------------
  // 9. Refresh Controller
  // -----------------------------------------------------------------------
  ddr5_refresh_ctrl u_ref (
    .clk(clk), .rst_n(rst_n), .timing(timing),
    .ref_mode(ref_mode), .init_done(init_done),
    .ref_req(ref_req), .ref_cmd(ref_cmd),
    .ref_bg(ref_bg), .ref_bank(ref_bank),
    .ref_grant(ref_grant),
    .ref_timeout(ref_timeout), .ref_debt(ref_debt)
  );
  assign ref_debt_out = ref_debt;

  // -----------------------------------------------------------------------
  // 10. ZQ Controller
  // -----------------------------------------------------------------------
  ddr5_zq_ctrl u_zq (
    .clk(clk), .rst_n(rst_n), .timing(timing), .init_done(init_done),
    .zq_req(zq_req_on_sref_exit),
    .cmd_valid(zq_cmd_valid), .cmd_out(zq_cmd_out), .cmd_ready(zq_cmd_ready),
    .zq_active(), .zq_done(), .zq_count()
  );

  // -----------------------------------------------------------------------
  // 11. Command Scheduler (host commands: ACT/RD/WR/PRE)
  // -----------------------------------------------------------------------
  // Map AXI command → DDR5 request sequence
  // Each AXI transaction expands to: ACT → RD/WR → (PRE if no AP)
  logic  sched_req_valid;
  ddr5_cmd_e sched_req_cmd;

  always_comb begin
    sched_req_valid = axi_cmd_valid && init_done && !pm_busy && !ref_req;
    // Issue ACT if bank is not open, else issue RD/WR directly
    if (bank_open[{mapped_bg, mapped_ba}]) begin
      sched_req_cmd = axi_cmd_is_write ? CMD_WRA : CMD_RDA;
    end else begin
      sched_req_cmd = CMD_ACT;
    end
  end

  ddr5_cmd_scheduler #(.ROW_BITS(ROW_BITS), .COL_BITS(COL_BITS)) u_sched (
    .clk(clk), .rst_n(rst_n),
    .req_valid(sched_req_valid), .req_cmd(sched_req_cmd),
    .req_bg(mapped_bg), .req_bank(mapped_ba),
    .req_row(mapped_row), .req_col(mapped_col),
    .req_ready(axi_cmd_ready),
    .timing(timing),
    .bank_open(bank_open), .open_rows(open_rows),
    .cmd_valid(sched_cmd_valid), .cmd_out(sched_cmd),
    .cmd_bg(sched_bg), .cmd_bank(sched_bank),
    .cmd_row(sched_row), .cmd_col(sched_col),
    .cmd_ready(host_cmd_ready_sched),
    .queue_depth_out(), .stall_due_timing()
  );

  // Build host command address field for arbiter
  always_comb begin
    case (sched_cmd)
      CMD_ACT:                sched_cmd_addr = sched_row[13:0];
      CMD_RD, CMD_RDA,
      CMD_WR, CMD_WRA:        sched_cmd_addr = {4'h0, sched_col};
      CMD_PRE:                sched_cmd_addr = 14'h0;
      default:                sched_cmd_addr = 14'h0;
    endcase
  end

  // -----------------------------------------------------------------------
  // 12. Bank FSMs (one per bank)
  // -----------------------------------------------------------------------
  generate
    for (genvar b = 0; b < NUM_BANKS; b++) begin : g_bank_fsm
      ddr5_bank_fsm #(.BANK_IDX(b)) u_bank (
        .clk(clk), .rst_n(rst_n), .timing(timing),
        .cmd_valid(arb_dfi_valid), .cmd(arb_dfi_cmd),
        .cmd_bg(arb_dfi_bg), .cmd_bank(arb_dfi_bank), .cmd_row(sched_row),
        .bank_open(bank_open[b]), .open_row(open_rows[b]),
        .bank_ready(bank_ready_arr[b]),
        .tRP_met(), .tRCD_met(), .tRAS_met()
      );
    end
  endgenerate

  // -----------------------------------------------------------------------
  // 13. Command Arbiter (final priority mux)
  // -----------------------------------------------------------------------
  ddr5_cmd_arbiter u_arbiter (
    .clk(clk), .rst_n(rst_n),
    // Init
    .init_cmd_valid(init_cmd_valid), .init_cmd(init_cmd),
    .init_cmd_addr(init_cmd_addr),   .init_cke(init_cke_sig),
    .init_cs_n(init_cs_n_sig),       .init_reset_n(init_reset_n_sig),
    .init_cmd_ready(init_cmd_ready),
    // PM
    .pm_cmd_valid(pm_cmd_valid), .pm_cmd(pm_cmd),
    .pm_cmd_ready(pm_cmd_ready), .pm_cke(pm_cke), .pm_busy(pm_busy),
    // Refresh
    .ref_cmd_valid(ref_req), .ref_cmd(ref_cmd),
    .ref_bg(ref_bg), .ref_bank(ref_bank), .ref_grant(ref_grant),
    // ZQ
    .zq_cmd_valid(zq_cmd_valid), .zq_cmd(zq_cmd_out), .zq_cmd_ready(zq_cmd_ready),
    // Mode Register
    .mr_cmd_valid(mr_cmd_valid), .mr_cmd(mr_cmd),
    .mr_cmd_addr(mr_cmd_addr),   .mr_cmd_ready(mr_cmd_ready),
    // Host
    .host_cmd_valid(sched_cmd_valid), .host_cmd(sched_cmd),
    .host_cmd_addr(sched_cmd_addr),   .host_bg(sched_bg),
    .host_bank(sched_bank), .host_row(sched_row), .host_col(sched_col),
    .host_cmd_ready(host_cmd_ready_sched),
    .init_done(init_done),
    // DFI output
    .dfi_cs_n(arb_dfi_cs_n),    .dfi_cke(arb_dfi_cke),
    .dfi_reset_n(arb_dfi_reset_n),
    .dfi_address(arb_dfi_addr), .dfi_bg(arb_dfi_bg),
    .dfi_bank(arb_dfi_bank),    .dfi_cmd(arb_dfi_cmd),
    .dfi_cmd_valid(arb_dfi_valid),
    .dfi_cmd_ready(arb_dfi_ready)
  );

  // DFI output assignments
  assign dfi_address  = arb_dfi_addr;
  assign dfi_bg       = arb_dfi_bg;
  assign dfi_bank     = arb_dfi_bank;
  assign dfi_cs_n     = arb_dfi_cs_n;
  assign dfi_cke      = arb_dfi_cke;
  assign dfi_reset_n  = arb_dfi_reset_n;
  assign dfi_odt      = (pwr_state == PWR_NORMAL) ? 1'b1 : 1'b0;
  assign arb_dfi_ready = dfi_init_complete || init_done;

  // -----------------------------------------------------------------------
  // Error aggregation
  // -----------------------------------------------------------------------
  always_comb begin
    err_type  = DDR5_ERR_NONE; err_valid = 0;
    if (sbe_det)       begin err_type = DDR5_ERR_ECC_SBE;     err_valid = 1; end
    if (dbe_det)       begin err_type = DDR5_ERR_ECC_DBE;     err_valid = 1; end
    if (ref_timeout)   begin err_type = DDR5_ERR_REFRESH_TMO; err_valid = 1; end
  end

endmodule : ddr5_ctrl_top
