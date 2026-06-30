// DDR5 IP Top-Level
// Integrates: AXI4 host interface → Controller → PHY → DRAM pads
import ddr5_pkg::*;

module ddr5_ip_top #(
  parameter int DQ_WIDTH   = 32,
  parameter int DQS_WIDTH  = DQ_WIDTH/8,
  parameter int ROW_BITS   = 17,
  parameter int COL_BITS   = 10,
  parameter int AXI_ID_W   = 8,
  parameter string SPEED   = "DDR5_6400"
)(
  input  logic              core_clk,
  input  logic              rst_n,
  input  link_speed_e       speed_grade,
  // AXI4 Host Interface
  input  logic              s_axi_awvalid, output logic s_axi_awready,
  input  logic [63:0]       s_axi_awaddr,
  input  logic [7:0]        s_axi_awlen,
  input  logic [AXI_ID_W-1:0] s_axi_awid,
  input  logic              s_axi_wvalid,  output logic s_axi_wready,
  input  logic [DQ_WIDTH*8-1:0] s_axi_wdata,
  input  logic [DQ_WIDTH-1:0]   s_axi_wstrb,
  input  logic              s_axi_wlast,
  output logic              s_axi_bvalid,  input  logic s_axi_bready,
  output logic [1:0]        s_axi_bresp,
  output logic [AXI_ID_W-1:0] s_axi_bid,
  input  logic              s_axi_arvalid, output logic s_axi_arready,
  input  logic [63:0]       s_axi_araddr,
  input  logic [7:0]        s_axi_arlen,
  input  logic [AXI_ID_W-1:0] s_axi_arid,
  output logic              s_axi_rvalid,  input  logic s_axi_rready,
  output logic [DQ_WIDTH*8-1:0] s_axi_rdata,
  output logic [1:0]        s_axi_rresp,
  output logic              s_axi_rlast,
  output logic [AXI_ID_W-1:0] s_axi_rid,
  // Configuration interface (APB)
  input  logic              cfg_psel, cfg_penable, cfg_pwrite,
  input  logic [11:0]       cfg_paddr,
  input  logic [31:0]       cfg_pwdata,
  output logic [31:0]       cfg_prdata,
  output logic              cfg_pready, cfg_pslverr,
  // DRAM interface
  output logic [13:0]       dram_ca,
  output logic              dram_cs_n, dram_cke, dram_odt, dram_reset_n,
  output logic              dram_ck_t, dram_ck_c,
  inout  wire [DQ_WIDTH-1:0]    dram_dq,
  inout  wire [DQS_WIDTH-1:0]   dram_dqs_t, dram_dqs_c,
  output logic [DQS_WIDTH-1:0]  dram_dm,
  input  logic              dram_alert_n,
  // Status outputs
  output logic              init_done,
  output logic              dll_locked,
  output ddr5_error_e       aer_err_type,
  output logic              aer_err_valid,
  output logic [7:0]        ref_debt,
  output power_state_e      pwr_state
);

  // -----------------------------------------------------------------------
  // Configuration registers (APB slave)
  // -----------------------------------------------------------------------
  ddr5_timing_t      timing;
  ddr5_mode_regs_t   mode_regs;
  refresh_mode_e     ref_mode;
  ecc_mode_e         ecc_mode;
  train_mode_e       train_mode;

  always_ff @(posedge core_clk or negedge rst_n) begin
    if (!rst_n) begin
      timing    <= ddr5_4800_timing();
      mode_regs <= '{mr0:8'h14,mr2:8'h0,mr3:8'h1,mr4:8'h0,mr5:8'hCC,
                     mr6:8'h4,mr7:8'h4,mr8:8'h40,mr10:8'h4,mr11:8'h4,
                     mr13:8'h4,mr15:8'h1,mr17:8'h4,mr24:8'h0,mr28:8'h0};
      ref_mode  <= REF_NORMAL;
      ecc_mode  <= ECC_SEC_DED;
      train_mode<= TRAIN_NONE;
      cfg_prdata<= '0; cfg_pready <= 1; cfg_pslverr <= 0;
    end else if (cfg_psel && cfg_penable) begin
      cfg_pready <= 1;
      if (cfg_pwrite) begin
        case (cfg_paddr)
          12'h000: timing.tCL      <= int'(cfg_pwdata[7:0]);
          12'h004: timing.tCWL     <= int'(cfg_pwdata[7:0]);
          12'h008: timing.tRCD     <= int'(cfg_pwdata[7:0]);
          12'h00C: timing.tRP      <= int'(cfg_pwdata[7:0]);
          12'h010: timing.tRAS     <= int'(cfg_pwdata[7:0]);
          12'h014: timing.tRFC     <= int'(cfg_pwdata);
          12'h018: timing.tREFI    <= int'(cfg_pwdata);
          12'h01C: timing.tWR      <= int'(cfg_pwdata[7:0]);
          12'h020: ref_mode        <= refresh_mode_e'(cfg_pwdata[2:0]);
          12'h024: ecc_mode        <= ecc_mode_e'(cfg_pwdata[1:0]);
          12'h028: train_mode      <= train_mode_e'(cfg_pwdata[2:0]);
          12'h100: mode_regs.mr0   <= cfg_pwdata[7:0];
          12'h104: mode_regs.mr2   <= cfg_pwdata[7:0];
          12'h108: mode_regs.mr3   <= cfg_pwdata[7:0];
          12'h10C: mode_regs.mr5   <= cfg_pwdata[7:0];
          12'h110: mode_regs.mr6   <= cfg_pwdata[7:0];
          12'h114: mode_regs.mr7   <= cfg_pwdata[7:0];
          12'h118: mode_regs.mr8   <= cfg_pwdata[7:0];
          12'h11C: mode_regs.mr13  <= cfg_pwdata[7:0];
          12'h120: mode_regs.mr15  <= cfg_pwdata[7:0];
          default: ;
        endcase
      end else begin
        case (cfg_paddr)
          12'h000: cfg_prdata <= timing.tCL;
          12'h020: cfg_prdata <= ref_mode;
          12'h024: cfg_prdata <= ecc_mode;
          12'h200: cfg_prdata <= {31'h0, init_done};
          12'h204: cfg_prdata <= {24'h0, ref_debt};
          12'h208: cfg_prdata <= aer_err_type;
          12'h20C: cfg_prdata <= dll_locked;
          default: cfg_prdata <= 32'hDEAD_C0DE;
        endcase
      end
    end
  end

  // -----------------------------------------------------------------------
  // DFI wires
  // -----------------------------------------------------------------------
  logic [13:0]        dfi_address;
  logic [2:0]         dfi_bg;
  logic [1:0]         dfi_bank;
  logic               dfi_cs_n, dfi_cke, dfi_odt, dfi_reset_n;
  logic [DQ_WIDTH*8-1:0] dfi_wrdata, dfi_rddata;
  logic [DQ_WIDTH-1:0]   dfi_wrmask;
  logic               dfi_wrdata_en, dfi_rddata_valid, dfi_init_complete;

  // -----------------------------------------------------------------------
  // Controller Top
  // -----------------------------------------------------------------------
  ddr5_ctrl_top #(.DQ_WIDTH(DQ_WIDTH), .ROW_BITS(ROW_BITS), .COL_BITS(COL_BITS)) u_ctrl (
    .clk(core_clk), .rst_n(rst_n),
    .axi_awvalid(s_axi_awvalid), .axi_awaddr(s_axi_awaddr), .axi_awlen(s_axi_awlen),
    .axi_awready(s_axi_awready),
    .axi_wvalid(s_axi_wvalid), .axi_wdata(s_axi_wdata), .axi_wstrb(s_axi_wstrb),
    .axi_wready(s_axi_wready),
    .axi_bvalid(s_axi_bvalid), .axi_bready(s_axi_bready), .axi_bresp(s_axi_bresp),
    .axi_arvalid(s_axi_arvalid), .axi_araddr(s_axi_araddr), .axi_arlen(s_axi_arlen),
    .axi_arready(s_axi_arready),
    .axi_rvalid(s_axi_rvalid), .axi_rdata(s_axi_rdata), .axi_rresp(s_axi_rresp),
    .axi_rready(s_axi_rready),
    .timing(timing), .mode_regs(mode_regs), .ref_mode(ref_mode), .ecc_mode(ecc_mode),
    .dfi_address(dfi_address), .dfi_bg(dfi_bg), .dfi_bank(dfi_bank),
    .dfi_cs_n(dfi_cs_n), .dfi_cke(dfi_cke), .dfi_odt(dfi_odt), .dfi_reset_n(dfi_reset_n),
    .dfi_wrdata(dfi_wrdata), .dfi_wrmask(dfi_wrmask), .dfi_wrdata_en(dfi_wrdata_en),
    .dfi_rddata(dfi_rddata), .dfi_rddata_valid(dfi_rddata_valid),
    .dfi_init_start(), .dfi_init_complete(dfi_init_complete),
    .err_type(aer_err_type), .err_valid(aer_err_valid),
    .init_done(init_done), .pwr_state(pwr_state), .ref_debt_out(ref_debt)
  );

  // -----------------------------------------------------------------------
  // PHY Top
  // -----------------------------------------------------------------------
  logic train_done_phy;
  ddr5_phy_top #(.DQ_WIDTH(DQ_WIDTH)) u_phy (
    .clk(core_clk), .rst_n(rst_n), .speed(speed_grade),
    .dfi_address(dfi_address), .dfi_bg(dfi_bg), .dfi_bank(dfi_bank),
    .dfi_cs_n(dfi_cs_n), .dfi_cke(dfi_cke), .dfi_odt(dfi_odt), .dfi_reset_n(dfi_reset_n),
    .dfi_wrdata(dfi_wrdata), .dfi_wrmask(dfi_wrmask), .dfi_wrdata_en(dfi_wrdata_en),
    .dfi_rddata_en(1'b1), .dfi_t_rddata_en(5'(timing.tCL)),
    .dfi_rddata(dfi_rddata), .dfi_rddata_valid(dfi_rddata_valid),
    .dfi_init_complete(dfi_init_complete),
    .train_mode(train_mode), .train_done(train_done_phy),
    .rdqs_delay(), .wdqs_delay(), .vref_dq(),
    .dram_ca(dram_ca), .dram_cs_n(dram_cs_n), .dram_cke(dram_cke),
    .dram_odt(dram_odt), .dram_reset_n(dram_reset_n),
    .dram_ck_t(dram_ck_t), .dram_ck_c(dram_ck_c),
    .pad_dq(dram_dq), .pad_dqs_t(dram_dqs_t), .pad_dqs_c(dram_dqs_c),
    .pad_dm(dram_dm), .dll_locked(dll_locked)
  );

  // AXI bookkeeping (ID passthrough, rlast)
  assign s_axi_bid   = s_axi_awid;
  assign s_axi_rid   = s_axi_arid;
  assign s_axi_rlast = 1'b1; // Single-beat model

endmodule : ddr5_ip_top
