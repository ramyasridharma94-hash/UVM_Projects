// DDR5 IP PHY Top — DLL + DFI Controller + IO Buffers
import ddr5_pkg::*;

module ddr5_phy_top #(
  parameter int DQ_WIDTH  = 32,
  parameter int DQS_WIDTH = DQ_WIDTH/8
)(
  input  logic              clk,
  input  logic              rst_n,
  input  link_speed_e       speed,
  // DFI
  input  logic [13:0]       dfi_address,
  input  logic [2:0]        dfi_bg,
  input  logic [1:0]        dfi_bank,
  input  logic              dfi_cs_n, dfi_cke, dfi_odt, dfi_reset_n,
  input  logic [DQ_WIDTH*8-1:0] dfi_wrdata,
  input  logic [DQ_WIDTH-1:0]   dfi_wrmask,
  input  logic              dfi_wrdata_en, dfi_rddata_en,
  input  logic [4:0]        dfi_t_rddata_en,
  output logic [DQ_WIDTH*8-1:0] dfi_rddata,
  output logic              dfi_rddata_valid,
  output logic              dfi_init_complete,
  // Training
  input  train_mode_e       train_mode,
  output logic              train_done,
  output logic [4:0]        rdqs_delay, wdqs_delay,
  output logic [7:0]        vref_dq,
  // DRAM pads
  output logic [13:0]       dram_ca,
  output logic              dram_cs_n, dram_cke, dram_odt, dram_reset_n,
  output logic              dram_ck_t, dram_ck_c,
  inout  wire [DQ_WIDTH-1:0]    pad_dq,
  inout  wire [DQS_WIDTH-1:0]   pad_dqs_t,
  inout  wire [DQS_WIDTH-1:0]   pad_dqs_c,
  output logic [DQS_WIDTH-1:0]  pad_dm,
  output logic              dll_locked
);

  // Internal wires
  logic        clk_0, clk_90, clk_180, clk_270;
  logic [4:0]  dll_code;
  logic [1:0]  dll_status;
  logic [DQ_WIDTH-1:0] dq_tx, dq_rx;
  logic [DQS_WIDTH-1:0] dqs_tx, dqs_rx, dm_tx;
  logic        dq_oe;
  logic [DQS_WIDTH-1:0] dqs_oe;
  logic        train_ack;
  logic [4:0]  rdqs_d, wdqs_d;
  logic [7:0]  vref_d;

  // -----------------------------------------------------------------------
  // DLL
  // -----------------------------------------------------------------------
  ddr5_dll u_dll (
    .clk_ref(clk), .rst_n(rst_n), .dll_en(1'b1),
    .dll_phase_sel(5'd8), .speed(speed),
    .clk_0(clk_0), .clk_90(clk_90), .clk_180(clk_180), .clk_270(clk_270),
    .dll_locked(dll_locked), .dll_code(dll_code), .dll_status(dll_status)
  );

  // CK differential
  assign dram_ck_t = clk_0;
  assign dram_ck_c = clk_180;

  // -----------------------------------------------------------------------
  // DFI Controller
  // -----------------------------------------------------------------------
  ddr5_dfi_ctrl #(.DQ_WIDTH(DQ_WIDTH)) u_dfi (
    .dfi_clk(clk), .rst_n(rst_n),
    .dfi_address(dfi_address), .dfi_bg(dfi_bg), .dfi_bank(dfi_bank),
    .dfi_cs_n(dfi_cs_n), .dfi_cke(dfi_cke), .dfi_odt(dfi_odt), .dfi_reset_n(dfi_reset_n),
    .dfi_wrdata(dfi_wrdata), .dfi_wrmask(dfi_wrmask), .dfi_wrdata_en(dfi_wrdata_en),
    .dfi_rddata_en(dfi_rddata_en), .dfi_t_rddata_en(dfi_t_rddata_en), .dfi_t_wrdata(5'd4),
    .dfi_rddata(dfi_rddata), .dfi_rddata_valid(dfi_rddata_valid),
    .rdqs_delay(rdqs_d), .wdqs_delay(wdqs_d),
    .dram_ca(dram_ca), .dram_bg(), .dram_bank(),
    .dram_cs_n(dram_cs_n), .dram_cke(dram_cke), .dram_odt(dram_odt),
    .dram_reset_n(dram_reset_n),
    .dram_dq_out(dq_tx), .dram_dq_in(dq_rx), .dram_dq_oe(dq_oe),
    .dram_dqs_t(dqs_tx), .dram_dqs_c(), .dram_dm(dm_tx),
    .train_mode(train_mode), .train_ack(train_ack)
  );

  // -----------------------------------------------------------------------
  // IO Buffers
  // -----------------------------------------------------------------------
  assign dqs_oe = {DQS_WIDTH{dq_oe}};

  ddr5_io_buf #(.DQ_WIDTH(DQ_WIDTH)) u_io (
    .clk(clk), .rst_n(rst_n),
    .drv_pull_up(5'd2), .drv_pull_dn(5'd2),
    .rtt_nom_wr(6'd4),  .rtt_nom_rd(6'd4),
    .odt_en(1'b1),
    .dq_tx(dq_tx), .dq_oe(dq_oe),
    .dqs_tx(dqs_tx), .dqs_oe(dqs_oe), .dm_tx(dm_tx),
    .dq_rx(dq_rx), .dqs_rx(dqs_rx),
    .pad_dq(pad_dq), .pad_dqs_t(pad_dqs_t), .pad_dqs_c(pad_dqs_c), .pad_dm(pad_dm),
    .zq_cal_en(1'b0), .zq_code_pu(), .zq_code_pd()
  );

  // -----------------------------------------------------------------------
  // Training engine (reuse from ddr5_phy.sv behavioral model)
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] { TR_IDLE, TR_WL, TR_DQS, TR_DQ, TR_CA, TR_VREF, TR_ZQ, TR_DONE } tr_e;
  tr_e tr_st;
  logic [7:0] tr_tmr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tr_st <= TR_IDLE; tr_tmr <= 0;
      rdqs_d <= 0; wdqs_d <= 0; vref_d <= 8'h50;
      train_done <= 0; dfi_init_complete <= 0;
    end else begin
      case (tr_st)
        TR_IDLE: begin
          if (dll_locked) begin
            if (train_mode != TRAIN_NONE)
              tr_st <= tr_e'({2'b0, train_mode[1:0]});
            else begin dfi_init_complete <= 1; train_done <= 1; end
          end
        end
        TR_WL: begin
          tr_tmr <= tr_tmr+1; if (tr_tmr==8'd63) begin wdqs_d<=5'd4; tr_st<=TR_DONE; end
        end
        TR_DQS: begin
          tr_tmr <= tr_tmr+1; if (tr_tmr==8'd63) begin rdqs_d<=5'd8; tr_st<=TR_DONE; end
        end
        TR_VREF: begin
          tr_tmr <= tr_tmr+1; if (tr_tmr==8'd63) begin vref_d<=8'h78; tr_st<=TR_DONE; end
        end
        TR_ZQ: begin
          tr_tmr <= tr_tmr+1; if (tr_tmr==8'd31) tr_st<=TR_DONE;
        end
        TR_DONE: begin
          train_done <= 1; dfi_init_complete <= 1; tr_st <= TR_IDLE;
        end
        default: tr_st <= TR_IDLE;
      endcase
    end
  end

  assign rdqs_delay = rdqs_d;
  assign wdqs_delay = wdqs_d;
  assign vref_dq    = vref_d;

endmodule : ddr5_phy_top
