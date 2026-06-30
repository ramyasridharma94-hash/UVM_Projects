// DDR5 IP Controller Top — integrates scheduler, bank FSMs, refresh, ZQ, ECC
import ddr5_pkg::*;

module ddr5_ctrl_top #(
  parameter int NUM_BG     = 8,
  parameter int NUM_BK     = 4,
  parameter int NUM_BANKS  = NUM_BG * NUM_BK,
  parameter int ROW_BITS   = 17,
  parameter int COL_BITS   = 10,
  parameter int DQ_WIDTH   = 32
)(
  input  logic              clk,
  input  logic              rst_n,
  // Host AXI-like interface
  input  logic              axi_awvalid,
  input  logic [63:0]       axi_awaddr,
  input  logic [7:0]        axi_awlen,
  output logic              axi_awready,
  input  logic              axi_wvalid,
  input  logic [DQ_WIDTH*8-1:0] axi_wdata,
  input  logic [DQ_WIDTH-1:0]   axi_wstrb,
  output logic              axi_wready,
  output logic              axi_bvalid,
  input  logic              axi_bready,
  output logic [1:0]        axi_bresp,
  input  logic              axi_arvalid,
  input  logic [63:0]       axi_araddr,
  input  logic [7:0]        axi_arlen,
  output logic              axi_arready,
  output logic              axi_rvalid,
  output logic [DQ_WIDTH*8-1:0] axi_rdata,
  output logic [1:0]        axi_rresp,
  input  logic              axi_rready,
  // Timing & config
  input  ddr5_timing_t      timing,
  input  ddr5_mode_regs_t   mode_regs,
  input  refresh_mode_e     ref_mode,
  input  ecc_mode_e         ecc_mode,
  // DFI outputs
  output logic [13:0]       dfi_address,
  output logic [2:0]        dfi_bg,
  output logic [1:0]        dfi_bank,
  output logic              dfi_cs_n,
  output logic              dfi_cke,
  output logic              dfi_odt,
  output logic              dfi_reset_n,
  output logic [DQ_WIDTH*8-1:0] dfi_wrdata,
  output logic [DQ_WIDTH-1:0]   dfi_wrmask,
  output logic              dfi_wrdata_en,
  input  logic [DQ_WIDTH*8-1:0] dfi_rddata,
  input  logic              dfi_rddata_valid,
  output logic              dfi_init_start,
  input  logic              dfi_init_complete,
  // Errors
  output ddr5_error_e       err_type,
  output logic              err_valid,
  // Status
  output logic              init_done,
  output power_state_e      pwr_state,
  output logic [7:0]        ref_debt_out
);

  // -----------------------------------------------------------------------
  // Internal wires
  // -----------------------------------------------------------------------
  logic [NUM_BANKS-1:0]    bank_open;
  logic [ROW_BITS-1:0]     open_rows [0:NUM_BANKS-1];
  logic [NUM_BANKS-1:0]    bank_ready_arr;

  // Scheduler → command bus
  logic              sched_valid;
  ddr5_cmd_e         sched_cmd;
  logic [2:0]        sched_bg;
  logic [1:0]        sched_bank;
  logic [ROW_BITS-1:0] sched_row;
  logic [COL_BITS-1:0] sched_col;
  logic              sched_ready;

  // Refresh
  logic              ref_req, ref_grant;
  ddr5_cmd_e         ref_cmd;
  logic [2:0]        ref_bg;
  logic [1:0]        ref_bank;
  logic              ref_timeout;
  logic [7:0]        ref_debt;

  // ZQ
  logic              zq_cmd_valid;
  ddr5_cmd_e         zq_cmd;

  // ECC
  logic [DQ_WIDTH*8-1:0] ecc_enc_data;
  logic [DQ_WIDTH*8-1:0] ecc_dec_data;
  logic              sbe_det, dbe_det;

  // AXI → scheduler request
  logic              req_valid;
  ddr5_cmd_e         req_cmd;
  logic [2:0]        req_bg;
  logic [1:0]        req_bank;
  logic [ROW_BITS-1:0] req_row;
  logic [COL_BITS-1:0] req_col;
  logic              req_ready_sched;

  // -----------------------------------------------------------------------
  // AXI to DDR5 address mapping
  // -----------------------------------------------------------------------
  // Physical address: {bg[2:0], bank[1:0], row[16:0], col[9:0]} = 32b
  // AXI address bit assignments: [31:29]=BG, [28:27]=BA, [26:10]=ROW, [9:0]=COL
  always_comb begin
    req_bg   = axi_awaddr[31:29];
    req_bank = axi_awaddr[28:27];
    req_row  = axi_awaddr[26:10];
    req_col  = {axi_awaddr[9:2], 2'b0};
  end

  // Simplified AXI-to-scheduler bridge (single-request model)
  typedef enum logic [1:0] { AX_IDLE, AX_ACT, AX_DATA, AX_CPL } ax_state_e;
  ax_state_e aw_state, ar_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_state <= AX_IDLE; ar_state <= AX_IDLE;
      axi_awready <= 0; axi_wready <= 0; axi_bvalid <= 0;
      axi_arready <= 0; axi_rvalid <= 0;
      req_valid <= 0; req_cmd <= CMD_NOP;
      dfi_wrdata <= '0; dfi_wrmask <= '0; dfi_wrdata_en <= 0;
    end else begin
      axi_awready <= 0; axi_wready <= 0; axi_bvalid <= 0;
      axi_arready <= 0; req_valid <= 0;

      case (aw_state)
        AX_IDLE: begin
          if (axi_awvalid && init_done) begin
            axi_awready <= 1; req_valid <= 1; req_cmd <= CMD_ACT;
            aw_state    <= AX_ACT;
          end
        end
        AX_ACT: begin
          if (req_ready_sched) begin
            req_valid <= 1; req_cmd <= CMD_WR; axi_wready <= 1;
            aw_state  <= AX_DATA;
          end
        end
        AX_DATA: begin
          if (axi_wvalid) begin
            dfi_wrdata    <= axi_wdata;
            dfi_wrmask    <= ~axi_wstrb; // DDR5 mask is active-high
            dfi_wrdata_en <= 1;
            if (req_ready_sched) begin
              axi_bvalid <= 1; axi_bresp <= 2'b00;
              req_valid  <= 1; req_cmd <= CMD_PRE;
              aw_state   <= AX_IDLE; dfi_wrdata_en <= 0;
            end
          end
        end
        default: aw_state <= AX_IDLE;
      endcase

      // Read path
      case (ar_state)
        AX_IDLE: begin
          if (axi_arvalid && init_done) begin
            axi_arready <= 1; req_valid <= 1; req_cmd <= CMD_ACT;
            ar_state    <= AX_ACT;
          end
        end
        AX_ACT: begin
          if (req_ready_sched) begin
            req_valid <= 1; req_cmd <= CMD_RDA; // Auto-precharge
            ar_state  <= AX_CPL;
          end
        end
        AX_CPL: begin
          if (dfi_rddata_valid) begin
            axi_rvalid <= 1; axi_rdata <= ecc_dec_data; axi_rresp <= dbe_det ? 2'b10 : 2'b00;
            ar_state   <= AX_IDLE;
          end
        end
        default: ar_state <= AX_IDLE;
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // Command Scheduler
  // -----------------------------------------------------------------------
  ddr5_cmd_scheduler #(.ROW_BITS(ROW_BITS), .COL_BITS(COL_BITS)) u_sched (
    .clk(clk), .rst_n(rst_n),
    .req_valid(req_valid), .req_cmd(req_cmd),
    .req_bg(req_bg), .req_bank(req_bank), .req_row(req_row), .req_col(req_col),
    .req_ready(req_ready_sched),
    .timing(timing),
    .bank_open(bank_open), .open_rows(open_rows),
    .cmd_valid(sched_valid), .cmd_out(sched_cmd),
    .cmd_bg(sched_bg), .cmd_bank(sched_bank), .cmd_row(sched_row), .cmd_col(sched_col),
    .cmd_ready(1'b1),
    .queue_depth_out(), .stall_due_timing()
  );

  // -----------------------------------------------------------------------
  // Bank FSMs
  // -----------------------------------------------------------------------
  generate
    for (genvar b = 0; b < NUM_BANKS; b++) begin : bk_fsm
      ddr5_bank_fsm #(.BANK_IDX(b)) u_bank (
        .clk(clk), .rst_n(rst_n), .timing(timing),
        .cmd_valid(sched_valid), .cmd(sched_cmd),
        .cmd_bg(sched_bg), .cmd_bank(sched_bank), .cmd_row(sched_row),
        .bank_open(bank_open[b]), .open_row(open_rows[b]),
        .bank_ready(bank_ready_arr[b]),
        .tRP_met(), .tRCD_met(), .tRAS_met()
      );
    end
  endgenerate

  // -----------------------------------------------------------------------
  // Refresh Controller
  // -----------------------------------------------------------------------
  ddr5_refresh_ctrl u_ref (
    .clk(clk), .rst_n(rst_n), .timing(timing), .ref_mode(ref_mode),
    .init_done(init_done),
    .ref_req(ref_req), .ref_cmd(ref_cmd), .ref_bg(ref_bg), .ref_bank(ref_bank),
    .ref_grant(ref_req && !req_valid),
    .ref_timeout(ref_timeout), .ref_debt(ref_debt)
  );
  assign ref_debt_out = ref_debt;

  // -----------------------------------------------------------------------
  // ZQ Controller
  // -----------------------------------------------------------------------
  ddr5_zq_ctrl u_zq (
    .clk(clk), .rst_n(rst_n), .timing(timing), .init_done(init_done),
    .zq_req(1'b0),
    .cmd_valid(zq_cmd_valid), .cmd_out(zq_cmd), .cmd_ready(1'b1),
    .zq_active(), .zq_done(), .zq_count()
  );

  // -----------------------------------------------------------------------
  // ECC
  // -----------------------------------------------------------------------
  ddr5_ecc u_ecc_enc (
    .clk(clk), .rst_n(rst_n), .ecc_en(ecc_mode != ECC_OFF),
    .enc_data_in(axi_wdata[63:0]), .enc_data_out(ecc_enc_data[71:0]),
    .dec_data_in(dfi_rddata[71:0]), .dec_data_out(ecc_dec_data[63:0]),
    .sbe_detected(sbe_det), .dbe_detected(dbe_det), .syndrome(), .error_bit_pos()
  );

  // -----------------------------------------------------------------------
  // DFI command drive
  // -----------------------------------------------------------------------
  always_comb begin
    dfi_cs_n = !sched_valid;
    dfi_bg   = sched_bg;
    dfi_bank = sched_bank;
    case (sched_cmd)
      CMD_ACT:  dfi_address = sched_row[13:0];
      CMD_WR, CMD_WRA, CMD_RD, CMD_RDA:
                dfi_address = {4'h0, sched_col};
      CMD_REF:  dfi_address = 14'h0001;
      CMD_MRS:  dfi_address = {6'h0, sched_row[7:0]};
      default:  dfi_address = 14'h0;
    endcase
  end

  assign dfi_cke      = 1'b1;
  assign dfi_odt      = 1'b0;
  assign dfi_reset_n  = rst_n;
  assign dfi_init_start = !init_done;

  // Error mux
  always_comb begin
    err_type  = DDR5_ERR_NONE; err_valid = 0;
    if (sbe_det) begin err_type = DDR5_ERR_ECC_SBE; err_valid = 1; end
    if (dbe_det) begin err_type = DDR5_ERR_ECC_DBE; err_valid = 1; end
    if (ref_timeout) begin err_type = DDR5_ERR_REFRESH_TMO; err_valid = 1; end
  end

  // Init sequencer (reuse from ddr5_ctrl)
  logic [15:0] init_timer;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin init_done <= 0; init_timer <= 0; pwr_state <= PWR_NORMAL; end
    else begin
      if (!init_done) begin
        init_timer <= init_timer + 1;
        if (dfi_init_complete || init_timer > 16'd1000) init_done <= 1;
      end
    end
  end

endmodule : ddr5_ctrl_top
