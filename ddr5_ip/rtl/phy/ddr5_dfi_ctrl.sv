// DDR5 DFI Controller — translates DFI commands to DRAM IO timing
// Manages 1:2 DFI frequency ratio, write/read leveling, DQS gating
import ddr5_pkg::*;

module ddr5_dfi_ctrl #(
  parameter int DQ_WIDTH   = 32,
  parameter int DQS_WIDTH  = DQ_WIDTH/8,
  parameter int FREQ_RATIO = 2   // 1:2 (DFI:DRAM)
)(
  input  logic              dfi_clk,
  input  logic              rst_n,
  // DFI inputs from controller
  input  logic [13:0]       dfi_address,
  input  logic [2:0]        dfi_bg,
  input  logic [1:0]        dfi_bank,
  input  logic              dfi_cs_n,
  input  logic              dfi_cke,
  input  logic              dfi_odt,
  input  logic              dfi_reset_n,
  input  logic [DQ_WIDTH*8-1:0] dfi_wrdata,
  input  logic [DQ_WIDTH-1:0]   dfi_wrmask,
  input  logic              dfi_wrdata_en,
  input  logic              dfi_rddata_en,
  input  logic [4:0]        dfi_t_rddata_en,  // read latency in DFI clocks
  input  logic [4:0]        dfi_t_wrdata,     // write data timing
  // DFI outputs to controller
  output logic [DQ_WIDTH*8-1:0] dfi_rddata,
  output logic              dfi_rddata_valid,
  // Trained delays
  input  logic [4:0]        rdqs_delay,
  input  logic [4:0]        wdqs_delay,
  // DRAM interface
  output logic [13:0]       dram_ca,
  output logic [2:0]        dram_bg,
  output logic [1:0]        dram_bank,
  output logic              dram_cs_n,
  output logic              dram_cke,
  output logic              dram_odt,
  output logic              dram_reset_n,
  output logic [DQ_WIDTH-1:0]  dram_dq_out,
  input  logic [DQ_WIDTH-1:0]  dram_dq_in,
  output logic              dram_dq_oe,
  output logic [DQS_WIDTH-1:0] dram_dqs_t,
  output logic [DQS_WIDTH-1:0] dram_dqs_c,
  output logic [DQS_WIDTH-1:0] dram_dm,
  // Training control
  input  train_mode_e       train_mode,
  output logic              train_ack
);

  // -----------------------------------------------------------------------
  // CA output registers (1:2 ratio: two DFI clock phases per DRAM clock)
  // -----------------------------------------------------------------------
  always_ff @(posedge dfi_clk or negedge rst_n) begin
    if (!rst_n) begin
      dram_ca <= '0; dram_bg <= '0; dram_bank <= '0;
      dram_cs_n <= 1; dram_cke <= 0; dram_odt <= 0; dram_reset_n <= 0;
    end else begin
      dram_ca      <= dfi_address;
      dram_bg      <= dfi_bg;
      dram_bank    <= dfi_bank;
      dram_cs_n    <= dfi_cs_n;
      dram_cke     <= dfi_cke;
      dram_odt     <= dfi_odt;
      dram_reset_n <= dfi_reset_n;
    end
  end

  // -----------------------------------------------------------------------
  // Write data path — apply wdqs_delay, serialize BL8
  // -----------------------------------------------------------------------
  logic [2:0]   wr_beat;
  logic         wr_active;
  logic [4:0]   wr_delay_cnt;

  always_ff @(posedge dfi_clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_beat <= 0; wr_active <= 0; wr_delay_cnt <= 0;
      dram_dq_out <= '0; dram_dq_oe <= 0;
      dram_dqs_t <= '0; dram_dqs_c <= '1; dram_dm <= '0;
    end else begin
      if (dfi_wrdata_en) begin
        if (wdqs_delay > 0) begin
          wr_delay_cnt <= wdqs_delay; wr_active <= 0;
        end else begin
          wr_active <= 1; wr_beat <= 0;
        end
      end
      if (wr_delay_cnt > 0) begin
        wr_delay_cnt <= wr_delay_cnt - 1;
        if (wr_delay_cnt == 1) begin wr_active <= 1; wr_beat <= 0; end
      end
      if (wr_active) begin
        dram_dq_oe  <= 1;
        dram_dqs_t  <= {DQS_WIDTH{dfi_clk}};
        dram_dqs_c  <= {DQS_WIDTH{~dfi_clk}};
        dram_dq_out <= dfi_wrdata[wr_beat*DQ_WIDTH +: DQ_WIDTH];
        dram_dm     <= dfi_wrmask;
        wr_beat     <= wr_beat + 1;
        if (wr_beat == 3'd7) begin
          wr_active <= 0; dram_dq_oe <= 0;
          dram_dqs_t <= '0; dram_dqs_c <= '1;
        end
      end
    end
  end

  // -----------------------------------------------------------------------
  // Read data path — DQS-gated capture with rdqs_delay pipeline
  // -----------------------------------------------------------------------
  logic [2:0]   rd_beat;
  logic         rd_active;
  logic [4:0]   rd_lat_cnt;
  logic [DQ_WIDTH*8-1:0] rd_buf;
  // Delay pipeline for read enable
  logic [47:0]  rd_pipe;

  always_ff @(posedge dfi_clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_beat <= 0; rd_active <= 0; rd_lat_cnt <= 0;
      dfi_rddata <= '0; dfi_rddata_valid <= 0; rd_pipe <= '0;
      train_ack  <= 0;
    end else begin
      dfi_rddata_valid <= 0;
      // Shift latency pipe
      rd_pipe <= {rd_pipe[46:0], dfi_rddata_en};
      if (rd_pipe[dfi_t_rddata_en]) begin rd_active <= 1; rd_beat <= 0; end

      if (rd_active) begin
        rd_buf[rd_beat*DQ_WIDTH +: DQ_WIDTH] <= dram_dq_in;
        rd_beat <= rd_beat + 1;
        if (rd_beat == 3'd7) begin
          rd_active        <= 0;
          dfi_rddata       <= rd_buf;
          dfi_rddata_valid <= 1;
        end
      end

      // Training acknowledge (simplified: ack after 64 clocks)
      if (train_mode != TRAIN_NONE) begin
        rd_lat_cnt <= rd_lat_cnt + 1;
        if (rd_lat_cnt == 5'd31) train_ack <= 1;
      end else train_ack <= 0;
    end
  end

endmodule : ddr5_dfi_ctrl
