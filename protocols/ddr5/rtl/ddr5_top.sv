// DDR5 Protocol Top — integrates controller + PHY
import ddr5_pkg::*;

module ddr5_top #(
  parameter int DQ_WIDTH  = 32,
  parameter int ROW_BITS  = 17,
  parameter int COL_BITS  = 10
)(
  input  logic              clk,
  input  logic              rst_n,
  // Host interface
  input  logic              req_valid,
  input  ddr5_cmd_e         req_cmd,
  input  logic [2:0]        req_bg,
  input  logic [1:0]        req_bank,
  input  logic [ROW_BITS-1:0] req_row,
  input  logic [COL_BITS-1:0] req_col,
  input  logic [DQ_WIDTH*8-1:0] req_wdata,
  input  logic [DQ_WIDTH-1:0]   req_wmask,
  output logic              req_ready,
  output logic              rd_valid,
  output logic [DQ_WIDTH*8-1:0] rd_data,
  // Training
  input  train_mode_e       train_mode,
  output logic              train_done,
  // Config
  input  ddr5_timing_t      timing,
  input  ddr5_mode_regs_t   mode_regs,
  // Error
  output ddr5_error_e       err_type,
  output logic              err_valid,
  // DRAM pads
  output logic [13:0]       dram_ca,
  output logic              dram_cs_n,
  output logic              dram_cke,
  output logic              dram_odt,
  output logic              dram_reset_n,
  output logic              dram_ck_t,
  output logic              dram_ck_c,
  output logic [DQ_WIDTH-1:0]  dq_out,
  input  logic [DQ_WIDTH-1:0]  dq_in,
  output logic              dq_oe,
  // Status
  output logic              init_done,
  output power_state_e      pwr_state,
  output logic              dll_locked
);

  // Internal DFI wires
  logic [13:0]        dfi_address;
  logic [2:0]         dfi_bg;
  logic [1:0]         dfi_bank;
  logic               dfi_cs_n, dfi_cke, dfi_odt, dfi_reset_n;
  logic [DQ_WIDTH*8-1:0] dfi_wrdata, dfi_rddata;
  logic [DQ_WIDTH-1:0]   dfi_wrmask;
  logic               dfi_wrdata_en, dfi_rddata_en, dfi_rddata_valid;
  logic               dfi_init_complete, dfi_error;
  logic [3:0]         dfi_error_info;

  ddr5_ctrl #(.DQ_WIDTH(DQ_WIDTH), .ROW_BITS(ROW_BITS), .COL_BITS(COL_BITS)) u_ctrl (
    .clk(clk), .rst_n(rst_n),
    .req_valid(req_valid), .req_cmd(req_cmd),
    .req_bg(req_bg),   .req_bank(req_bank),
    .req_row(req_row), .req_col(req_col),
    .req_wdata(req_wdata), .req_wmask(req_wmask),
    .req_ready(req_ready),
    .rd_valid(rd_valid),   .rd_data(rd_data),
    .dfi_address(dfi_address), .dfi_bg(dfi_bg), .dfi_bank(dfi_bank),
    .dfi_cs_n(dfi_cs_n),  .dfi_cke(dfi_cke),
    .dfi_odt(dfi_odt),    .dfi_reset_n(dfi_reset_n),
    .dfi_wrdata(dfi_wrdata), .dfi_wrmask(dfi_wrmask), .dfi_wrdata_en(dfi_wrdata_en),
    .dfi_rddata(dfi_rddata), .dfi_rddata_valid(dfi_rddata_valid),
    .timing(timing), .mode_regs(mode_regs),
    .err_type(err_type), .err_valid(err_valid),
    .init_done(init_done), .pwr_state(pwr_state)
  );

  ddr5_phy #(.DQ_WIDTH(DQ_WIDTH)) u_phy (
    .clk(clk), .rst_n(rst_n),
    .dfi_address(dfi_address), .dfi_bg(dfi_bg), .dfi_bank(dfi_bank),
    .dfi_cs_n(dfi_cs_n),  .dfi_cke(dfi_cke),
    .dfi_odt(dfi_odt),    .dfi_reset_n(dfi_reset_n),
    .dfi_wrdata(dfi_wrdata), .dfi_wrmask(dfi_wrmask), .dfi_wrdata_en(dfi_wrdata_en),
    .dfi_rddata_en(1'b1),
    .dfi_rddata(dfi_rddata), .dfi_rddata_valid(dfi_rddata_valid),
    .dfi_init_complete(dfi_init_complete),
    .dfi_error(dfi_error), .dfi_error_info(dfi_error_info),
    .train_mode(train_mode), .train_done(train_done),
    .rdqs_delay(), .wdqs_delay(), .vref_dq(),
    .dram_ca(dram_ca), .dram_cs_n(dram_cs_n), .dram_cke(dram_cke),
    .dram_odt(dram_odt), .dram_reset_n(dram_reset_n),
    .dram_ck_t(dram_ck_t), .dram_ck_c(dram_ck_c),
    .dq_out(dq_out), .dq_in(dq_in), .dq_oe(dq_oe),
    .dqs_t_out(), .dqs_c_out(), .dm_out(),
    .dll_lock_phase(), .dll_locked(dll_locked)
  );

  assign dfi_rddata_en = 1'b1;

endmodule : ddr5_top
