// DDR5 IP Top-Level (revised)
// Full stack: APB Config → DDR5 Ctrl Top (AXI4+sub-modules) → DDR5 PHY Top → DRAM pads
// Compatible with all ddr5_ctrl_top sub-modules: axi4_slave, addr_mapper,
// wr/rd_data_buf, init_fsm, mode_reg_ctrl, power_ctrl, bank_fsms(×32),
// cmd_scheduler, refresh_ctrl, zq_ctrl, ecc, cmd_arbiter
import ddr5_pkg::*;

module ddr5_ip_top #(
  parameter int DQ_WIDTH     = 32,
  parameter int DQS_WIDTH    = DQ_WIDTH/8,
  parameter int ROW_BITS     = 17,
  parameter int COL_BITS     = 10,
  parameter int AXI_ADDR_W   = 34,
  parameter int AXI_DATA_W   = DQ_WIDTH * 8,  // 256b = BL8 × 32b
  parameter int AXI_ID_W     = 8,
  parameter int CLK_FREQ_MHZ = 200,
  parameter int ADDR_POLICY  = 0
)(
  input  logic              core_clk,
  input  logic              rst_n,
  input  link_speed_e       speed_grade,

  // -----------------------------------------------------------------------
  // AXI4 Host Interface
  // -----------------------------------------------------------------------
  input  logic              s_axi_awvalid, output logic s_axi_awready,
  input  logic [AXI_ADDR_W-1:0] s_axi_awaddr,
  input  logic [7:0]        s_axi_awlen,
  input  logic [2:0]        s_axi_awsize,
  input  logic [1:0]        s_axi_awburst,
  input  logic [AXI_ID_W-1:0]  s_axi_awid,
  input  logic [2:0]        s_axi_awprot,
  input  logic [3:0]        s_axi_awcache,
  input  logic [3:0]        s_axi_awqos,

  input  logic              s_axi_wvalid,  output logic s_axi_wready,
  input  logic [AXI_DATA_W-1:0] s_axi_wdata,
  input  logic [AXI_DATA_W/8-1:0] s_axi_wstrb,
  input  logic              s_axi_wlast,

  output logic              s_axi_bvalid,  input  logic s_axi_bready,
  output logic [1:0]        s_axi_bresp,
  output logic [AXI_ID_W-1:0]  s_axi_bid,

  input  logic              s_axi_arvalid, output logic s_axi_arready,
  input  logic [AXI_ADDR_W-1:0] s_axi_araddr,
  input  logic [7:0]        s_axi_arlen,
  input  logic [2:0]        s_axi_arsize,
  input  logic [1:0]        s_axi_arburst,
  input  logic [AXI_ID_W-1:0]  s_axi_arid,
  input  logic [2:0]        s_axi_arprot,
  input  logic [3:0]        s_axi_arcache,
  input  logic [3:0]        s_axi_arqos,

  output logic              s_axi_rvalid,  input  logic s_axi_rready,
  output logic [AXI_DATA_W-1:0] s_axi_rdata,
  output logic [1:0]        s_axi_rresp,
  output logic              s_axi_rlast,
  output logic [AXI_ID_W-1:0]  s_axi_rid,

  // -----------------------------------------------------------------------
  // APB Configuration Interface (32 registers)
  // -----------------------------------------------------------------------
  input  logic              cfg_psel,
  input  logic              cfg_penable,
  input  logic              cfg_pwrite,
  input  logic [11:0]       cfg_paddr,
  input  logic [31:0]       cfg_pwdata,
  output logic [31:0]       cfg_prdata,
  output logic              cfg_pready,
  output logic              cfg_pslverr,

  // -----------------------------------------------------------------------
  // DRAM Physical Interface
  // -----------------------------------------------------------------------
  output logic [13:0]       dram_ca,
  output logic              dram_cs_n,
  output logic              dram_cke,
  output logic              dram_odt,
  output logic              dram_reset_n,
  output logic              dram_ck_t,
  output logic              dram_ck_c,
  inout  wire [DQ_WIDTH-1:0]    dram_dq,
  inout  wire [DQS_WIDTH-1:0]   dram_dqs_t,
  inout  wire [DQS_WIDTH-1:0]   dram_dqs_c,
  output logic [DQS_WIDTH-1:0]  dram_dm,
  input  logic              dram_alert_n,

  // -----------------------------------------------------------------------
  // Status / Debug Outputs
  // -----------------------------------------------------------------------
  output logic              init_done,
  output logic              dll_locked,
  output ddr5_error_e       aer_err_type,
  output logic              aer_err_valid,
  output logic [7:0]        ref_debt,
  output power_state_e      pwr_state,
  output logic [4:0]        wr_outstanding,
  output logic [4:0]        rd_outstanding
);

  // -----------------------------------------------------------------------
  // APB Configuration Register Bank
  // -----------------------------------------------------------------------
  ddr5_timing_t      timing;
  ddr5_mode_regs_t   mode_regs_cfg;
  refresh_mode_e     ref_mode;
  ecc_mode_e         ecc_mode;
  burst_len_e        burst_len_cfg;
  train_mode_e       train_mode;
  // Runtime requests decoded from APB
  logic              mrs_req,  mrs_ack;
  logic [7:0]        mrs_mr_addr, mrs_mr_data;
  logic              mrr_req,  mrr_valid;
  logic [7:0]        mrr_mr_addr, mrr_rd_data;
  logic              pd_req, sref_req, wake_req;

  always_ff @(posedge core_clk or negedge rst_n) begin
    if (!rst_n) begin
      timing        <= ddr5_4800_timing();
      mode_regs_cfg <= '{
        mr0:8'h14, mr2:8'h00, mr3:8'h01, mr4:8'h00,
        mr5:8'hCC, mr6:8'h04, mr7:8'h04, mr8:8'h40,
        mr10:8'h04, mr11:8'h04, mr13:8'h04, mr15:8'h01,
        mr17:8'h04, mr24:8'h00, mr28:8'h00
      };
      ref_mode      <= REF_NORMAL;
      ecc_mode      <= ECC_SEC_DED;
      burst_len_cfg <= BL8;
      train_mode    <= TRAIN_NONE;
      mrs_req       <= 0; mrr_req <= 0;
      mrs_mr_addr   <= '0; mrs_mr_data <= '0; mrr_mr_addr <= '0;
      pd_req  <= 0; sref_req <= 0; wake_req <= 0;
      cfg_prdata    <= '0; cfg_pready <= 1; cfg_pslverr <= 0;
    end else begin
      mrs_req  <= 0; mrr_req  <= 0;
      wake_req <= 0; pd_req   <= 0; sref_req <= 0;
      cfg_pready <= 1; cfg_pslverr <= 0;

      if (cfg_psel && cfg_penable) begin
        if (cfg_pwrite) begin
          case (cfg_paddr)
            // --- Timing ---
            12'h000: timing.tCL    <= int'(cfg_pwdata[7:0]);
            12'h004: timing.tCWL   <= int'(cfg_pwdata[7:0]);
            12'h008: timing.tRCD   <= int'(cfg_pwdata[7:0]);
            12'h00C: timing.tRP    <= int'(cfg_pwdata[7:0]);
            12'h010: timing.tRAS   <= int'(cfg_pwdata[7:0]);
            12'h014: timing.tRFC   <= int'(cfg_pwdata);
            12'h018: timing.tREFI  <= int'(cfg_pwdata);
            12'h01C: timing.tWR    <= int'(cfg_pwdata[7:0]);
            12'h020: timing.tFAW   <= int'(cfg_pwdata[7:0]);
            12'h024: timing.tRRD_S <= int'(cfg_pwdata[3:0]);
            12'h028: timing.tRRD_L <= int'(cfg_pwdata[3:0]);
            12'h02C: timing.tCCD_S <= int'(cfg_pwdata[3:0]);
            12'h030: timing.tCCD_L <= int'(cfg_pwdata[3:0]);
            12'h034: timing.tWTR_S <= int'(cfg_pwdata[3:0]);
            12'h038: timing.tWTR_L <= int'(cfg_pwdata[3:0]);
            12'h03C: timing.tRTP   <= int'(cfg_pwdata[3:0]);
            12'h040: timing.tXS    <= int'(cfg_pwdata[7:0]);
            12'h044: timing.tXP    <= int'(cfg_pwdata[3:0]);
            12'h048: timing.tZQinit<= int'(cfg_pwdata);
            12'h04C: timing.tZQoper<= int'(cfg_pwdata);
            // --- Control ---
            12'h050: ref_mode      <= refresh_mode_e'(cfg_pwdata[2:0]);
            12'h054: ecc_mode      <= ecc_mode_e'(cfg_pwdata[1:0]);
            12'h058: burst_len_cfg <= burst_len_e'(cfg_pwdata[1:0]);
            12'h05C: train_mode    <= train_mode_e'(cfg_pwdata[2:0]);
            // --- Power ---
            12'h060: pd_req        <= cfg_pwdata[0];
            12'h064: sref_req      <= cfg_pwdata[0];
            12'h068: wake_req      <= cfg_pwdata[0];
            // --- Mode Registers ---
            12'h100: mode_regs_cfg.mr0  <= cfg_pwdata[7:0];
            12'h104: mode_regs_cfg.mr2  <= cfg_pwdata[7:0];
            12'h108: mode_regs_cfg.mr3  <= cfg_pwdata[7:0];
            12'h10C: mode_regs_cfg.mr5  <= cfg_pwdata[7:0];
            12'h110: mode_regs_cfg.mr6  <= cfg_pwdata[7:0];
            12'h114: mode_regs_cfg.mr7  <= cfg_pwdata[7:0];
            12'h118: mode_regs_cfg.mr8  <= cfg_pwdata[7:0];
            12'h11C: mode_regs_cfg.mr10 <= cfg_pwdata[7:0];
            12'h120: mode_regs_cfg.mr13 <= cfg_pwdata[7:0];
            12'h124: mode_regs_cfg.mr15 <= cfg_pwdata[7:0];
            12'h128: mode_regs_cfg.mr17 <= cfg_pwdata[7:0];
            // --- Runtime MRS/MRR ---
            12'h180: begin
              mrs_req      <= 1;
              mrs_mr_addr  <= cfg_pwdata[15:8];
              mrs_mr_data  <= cfg_pwdata[7:0];
            end
            12'h184: begin
              mrr_req     <= 1;
              mrr_mr_addr <= cfg_pwdata[7:0];
            end
            default: cfg_pslverr <= 1;
          endcase
        end else begin  // Read
          case (cfg_paddr)
            12'h000: cfg_prdata <= timing.tCL;
            12'h004: cfg_prdata <= timing.tCWL;
            12'h008: cfg_prdata <= timing.tRCD;
            12'h00C: cfg_prdata <= timing.tRP;
            12'h010: cfg_prdata <= timing.tRAS;
            12'h014: cfg_prdata <= timing.tRFC;
            12'h050: cfg_prdata <= ref_mode;
            12'h054: cfg_prdata <= ecc_mode;
            12'h058: cfg_prdata <= burst_len_cfg;
            // --- Status ---
            12'h200: cfg_prdata <= {30'h0, dll_locked, init_done};
            12'h204: cfg_prdata <= {24'h0, ref_debt};
            12'h208: cfg_prdata <= aer_err_type;
            12'h20C: cfg_prdata <= {27'h0, wr_outstanding};
            12'h210: cfg_prdata <= {27'h0, rd_outstanding};
            12'h214: cfg_prdata <= pwr_state;
            12'h218: cfg_prdata <= {24'h0, mrr_rd_data};
            12'h21C: cfg_prdata <= {31'h0, mrr_valid};
            12'h220: cfg_prdata <= {31'h0, mrs_ack};
            default: cfg_prdata <= 32'hDEAD_C0DE;
          endcase
        end
      end
    end
  end

  // -----------------------------------------------------------------------
  // DFI wires between ctrl_top and phy_top
  // -----------------------------------------------------------------------
  logic [13:0]        dfi_address_w;
  logic [2:0]         dfi_bg_w;
  logic [1:0]         dfi_bank_w;
  logic               dfi_cs_n_w, dfi_cke_w, dfi_odt_w, dfi_reset_n_w;
  logic [AXI_DATA_W-1:0] dfi_wrdata_w, dfi_rddata_w;
  logic [DQ_WIDTH-1:0]   dfi_wrmask_w;
  logic               dfi_wrdata_en_w, dfi_rddata_en_w;
  logic               dfi_rddata_valid_w, dfi_init_complete_w;
  logic [7:0]         dfi_mrr_data_w;
  logic               dfi_mrr_valid_w;

  // -----------------------------------------------------------------------
  // DDR5 Controller Top
  // -----------------------------------------------------------------------
  ddr5_ctrl_top #(
    .DQ_WIDTH(DQ_WIDTH), .ROW_BITS(ROW_BITS), .COL_BITS(COL_BITS),
    .AXI_ADDR_W(AXI_ADDR_W), .AXI_ID_W(AXI_ID_W),
    .CLK_FREQ_MHZ(CLK_FREQ_MHZ), .ADDR_POLICY(ADDR_POLICY)
  ) u_ctrl_top (
    .clk(core_clk), .rst_n(rst_n),
    // AXI4
    .s_awvalid(s_axi_awvalid), .s_awready(s_axi_awready),
    .s_awaddr(s_axi_awaddr),   .s_awlen(s_axi_awlen),
    .s_awsize(s_axi_awsize),   .s_awburst(s_axi_awburst),
    .s_awid(s_axi_awid),       .s_awprot(s_axi_awprot),
    .s_awcache(s_axi_awcache), .s_awqos(s_axi_awqos),
    .s_wvalid(s_axi_wvalid),   .s_wready(s_axi_wready),
    .s_wdata(s_axi_wdata),     .s_wstrb(s_axi_wstrb),
    .s_wlast(s_axi_wlast),
    .s_bvalid(s_axi_bvalid),   .s_bready(s_axi_bready),
    .s_bresp(s_axi_bresp),     .s_bid(s_axi_bid),
    .s_arvalid(s_axi_arvalid), .s_arready(s_axi_arready),
    .s_araddr(s_axi_araddr),   .s_arlen(s_axi_arlen),
    .s_arsize(s_axi_arsize),   .s_arburst(s_axi_arburst),
    .s_arid(s_axi_arid),       .s_arprot(s_axi_arprot),
    .s_arcache(s_axi_arcache), .s_arqos(s_axi_arqos),
    .s_rvalid(s_axi_rvalid),   .s_rready(s_axi_rready),
    .s_rdata(s_axi_rdata),     .s_rresp(s_axi_rresp),
    .s_rlast(s_axi_rlast),     .s_rid(s_axi_rid),
    // Config
    .timing(timing), .mode_regs(mode_regs_cfg),
    .ref_mode(ref_mode), .ecc_mode(ecc_mode), .burst_len_cfg(burst_len_cfg),
    // Runtime MRS/MRR
    .mrs_req(mrs_req), .mrs_mr_addr(mrs_mr_addr), .mrs_mr_data(mrs_mr_data),
    .mrs_ack(mrs_ack),
    .mrr_req(mrr_req), .mrr_mr_addr(mrr_mr_addr),
    .mrr_rd_data(mrr_rd_data), .mrr_valid(mrr_valid),
    // Power
    .pd_req(pd_req), .sref_req(sref_req), .wake_req(wake_req),
    // DFI
    .dfi_address(dfi_address_w), .dfi_bg(dfi_bg_w), .dfi_bank(dfi_bank_w),
    .dfi_cs_n(dfi_cs_n_w), .dfi_cke(dfi_cke_w), .dfi_odt(dfi_odt_w),
    .dfi_reset_n(dfi_reset_n_w),
    .dfi_wrdata(dfi_wrdata_w), .dfi_wrmask(dfi_wrmask_w),
    .dfi_wrdata_en(dfi_wrdata_en_w), .dfi_rddata_en(dfi_rddata_en_w),
    .dfi_rddata(dfi_rddata_w), .dfi_rddata_valid(dfi_rddata_valid_w),
    .dfi_init_start(),         .dfi_init_complete(dfi_init_complete_w),
    .dfi_mrr_data(dfi_mrr_data_w), .dfi_mrr_valid(dfi_mrr_valid_w),
    // Status
    .err_type(aer_err_type), .err_valid(aer_err_valid),
    .init_done(init_done), .pwr_state(pwr_state),
    .ref_debt_out(ref_debt),
    .wr_outstanding(wr_outstanding), .rd_outstanding(rd_outstanding)
  );

  // -----------------------------------------------------------------------
  // DDR5 PHY Top
  // -----------------------------------------------------------------------
  logic train_done_phy;
  ddr5_phy_top #(.DQ_WIDTH(DQ_WIDTH)) u_phy_top (
    .clk(core_clk), .rst_n(rst_n), .speed(speed_grade),
    // DFI in
    .dfi_address(dfi_address_w), .dfi_bg(dfi_bg_w), .dfi_bank(dfi_bank_w),
    .dfi_cs_n(dfi_cs_n_w), .dfi_cke(dfi_cke_w), .dfi_odt(dfi_odt_w),
    .dfi_reset_n(dfi_reset_n_w),
    .dfi_wrdata(dfi_wrdata_w), .dfi_wrmask(dfi_wrmask_w),
    .dfi_wrdata_en(dfi_wrdata_en_w), .dfi_rddata_en(dfi_rddata_en_w),
    .dfi_t_rddata_en(5'(timing.tCL)),
    // DFI out
    .dfi_rddata(dfi_rddata_w), .dfi_rddata_valid(dfi_rddata_valid_w),
    .dfi_init_complete(dfi_init_complete_w),
    // Training
    .train_mode(train_mode), .train_done(train_done_phy),
    .rdqs_delay(), .wdqs_delay(), .vref_dq(),
    // DRAM pads
    .dram_ca(dram_ca), .dram_cs_n(dram_cs_n),
    .dram_cke(dram_cke), .dram_odt(dram_odt),
    .dram_reset_n(dram_reset_n),
    .dram_ck_t(dram_ck_t), .dram_ck_c(dram_ck_c),
    .pad_dq(dram_dq), .pad_dqs_t(dram_dqs_t), .pad_dqs_c(dram_dqs_c),
    .pad_dm(dram_dm),
    .dll_locked(dll_locked)
  );

  // MRR data path: PHY captures 8-bit MR data after CMD_MRR → DQ bus
  // In a real PHY this is routed through the DFI rddata path; here we
  // model it as a direct stub (real impl would decode from dfi_rddata)
  assign dfi_mrr_data_w = dfi_rddata_w[7:0];
  assign dfi_mrr_valid_w = dfi_rddata_valid_w;

endmodule : ddr5_ip_top
