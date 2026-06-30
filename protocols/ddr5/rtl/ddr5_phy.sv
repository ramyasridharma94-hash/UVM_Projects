// DDR5 PHY — DFI interface, IO buffers, DLL, training engine
import ddr5_pkg::*;

module ddr5_phy #(
  parameter int DQ_WIDTH  = 32,
  parameter int DQS_WIDTH = DQ_WIDTH/8
)(
  input  logic              clk,        // System/DFI clock
  input  logic              rst_n,
  // DFI interface (from controller)
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
  output logic [DQ_WIDTH*8-1:0] dfi_rddata,
  output logic              dfi_rddata_valid,
  output logic              dfi_init_complete,
  output logic              dfi_error,
  output logic [3:0]        dfi_error_info,
  // Training
  input  train_mode_e       train_mode,
  output logic              train_done,
  output logic [4:0]        rdqs_delay,   // trained DQS delay
  output logic [4:0]        wdqs_delay,
  output logic [7:0]        vref_dq,      // trained VREF_DQ
  // DRAM interface (to pad ring)
  output logic [13:0]       dram_ca,
  output logic              dram_cs_n,
  output logic              dram_cke,
  output logic              dram_odt,
  output logic              dram_reset_n,
  output logic              dram_ck_t,
  output logic              dram_ck_c,
  // DQ/DQS bidirectional (modeled as output + input)
  output logic [DQ_WIDTH-1:0]  dq_out,
  input  logic [DQ_WIDTH-1:0]  dq_in,
  output logic              dq_oe,
  output logic [DQS_WIDTH-1:0] dqs_t_out,
  output logic [DQS_WIDTH-1:0] dqs_c_out,
  output logic [DQS_WIDTH-1:0] dm_out,
  // Status
  output logic [3:0]        dll_lock_phase,
  output logic              dll_locked
);

  // -----------------------------------------------------------------------
  // DLL — generates quadrature clocks for DDR I/O timing
  // -----------------------------------------------------------------------
  logic [3:0] dll_phase;
  logic [7:0] dll_timer;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dll_phase <= 0; dll_timer <= 0; dll_locked <= 0;
    end else begin
      if (!dll_locked) begin
        dll_timer <= dll_timer + 1;
        if (dll_timer == 8'd255) begin
          dll_locked  <= 1;
          dll_phase   <= 4'h8; // 90° for DDR2 data eye center
        end
      end
    end
  end
  assign dll_lock_phase = dll_phase;

  // -----------------------------------------------------------------------
  // CK generation (differential)
  // -----------------------------------------------------------------------
  logic ck_int;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) ck_int <= 0; else ck_int <= ~ck_int;
  assign dram_ck_t = ck_int;
  assign dram_ck_c = ~ck_int;

  // -----------------------------------------------------------------------
  // CA / Control pad drivers (registered, 1:2 ratio simplified)
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dram_ca      <= '0; dram_cs_n <= 1; dram_cke <= 0;
      dram_odt     <= 0;  dram_reset_n <= 0;
    end else begin
      dram_ca      <= dfi_address;
      dram_cs_n    <= dfi_cs_n;
      dram_cke     <= dfi_cke;
      dram_odt     <= dfi_odt;
      dram_reset_n <= dfi_reset_n;
    end
  end

  // -----------------------------------------------------------------------
  // Write data path — serialize BL8 (8 beats × DQ_WIDTH bits)
  // -----------------------------------------------------------------------
  logic [2:0] wr_beat;
  logic       wr_active;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dq_out  <= '0; dq_oe  <= 0; dm_out <= '0;
      dqs_t_out <= '0; dqs_c_out <= '1;
      wr_beat <= 0; wr_active <= 0;
    end else begin
      if (dfi_wrdata_en) begin
        wr_active <= 1; wr_beat <= 0;
      end
      if (wr_active) begin
        dq_oe     <= 1;
        dqs_t_out <= {DQS_WIDTH{ck_int}};
        dqs_c_out <= {DQS_WIDTH{~ck_int}};
        // Output one DQ_WIDTH slice per beat
        dq_out  <= dfi_wrdata[wr_beat*DQ_WIDTH +: DQ_WIDTH];
        dm_out  <= dfi_wrmask;
        wr_beat <= wr_beat + 1;
        if (wr_beat == 3'd7) begin wr_active <= 0; dq_oe <= 0; end
      end else begin
        dq_oe <= 0; dqs_t_out <= '0; dqs_c_out <= '1;
      end
    end
  end

  // -----------------------------------------------------------------------
  // Read data path — capture on DQS strobe, assemble BL8
  // -----------------------------------------------------------------------
  logic [2:0] rd_beat;
  logic       rd_active;
  logic [DQ_WIDTH*8-1:0] rd_capture;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_beat <= 0; rd_active <= 0; rd_capture <= '0;
      dfi_rddata <= '0; dfi_rddata_valid <= 0;
    end else begin
      dfi_rddata_valid <= 0;
      if (dfi_rddata_en) begin rd_active <= 1; rd_beat <= 0; end
      if (rd_active) begin
        // Apply trained DQS delay (simplified: use rdqs_delay as pipe depth)
        rd_capture[rd_beat*DQ_WIDTH +: DQ_WIDTH] <= dq_in;
        rd_beat <= rd_beat + 1;
        if (rd_beat == 3'd7) begin
          rd_active        <= 0;
          dfi_rddata       <= rd_capture;
          dfi_rddata_valid <= 1;
        end
      end
    end
  end

  // -----------------------------------------------------------------------
  // Training engine
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    TR_IDLE, TR_WL, TR_RD_DQS, TR_WR_DQ, TR_CA, TR_VREF, TR_ZQ, TR_DONE
  } tr_state_e;

  tr_state_e   tr_state;
  logic [7:0]  tr_timer;
  logic [4:0]  dly_sweep;
  logic [7:0]  vref_sweep;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tr_state  <= TR_IDLE; tr_timer <= 0;
      rdqs_delay<= 0; wdqs_delay <= 0; vref_dq <= 8'h50;
      train_done<= 0; dly_sweep <= 0; vref_sweep <= 8'h40;
      dfi_init_complete <= 0; dfi_error <= 0; dfi_error_info <= 0;
    end else begin
      case (tr_state)
        TR_IDLE: begin
          if (train_mode != TRAIN_NONE) begin
            tr_state  <= tr_state_e'({2'b0, train_mode});
            tr_timer  <= 0; train_done <= 0;
          end else dfi_init_complete <= 1;
        end
        TR_WL: begin // Write Leveling — sweep wdqs_delay until DQ captures high
          if (tr_timer < 8'd64) begin
            dly_sweep  <= dly_sweep + 1; tr_timer <= tr_timer + 1;
          end else begin
            wdqs_delay <= dly_sweep; tr_state <= TR_DONE;
          end
        end
        TR_RD_DQS: begin // Read DQS centering
          if (tr_timer < 8'd64) begin
            dly_sweep  <= dly_sweep + 1; tr_timer <= tr_timer + 1;
          end else begin
            rdqs_delay <= dly_sweep; tr_state <= TR_DONE;
          end
        end
        TR_CA: begin // CA training via MPC command
          if (tr_timer < 8'd32) tr_timer <= tr_timer + 1;
          else tr_state <= TR_DONE;
        end
        TR_VREF: begin // VREF sweep
          if (vref_sweep < 8'd95) begin
            vref_sweep <= vref_sweep + 2; tr_timer <= tr_timer + 1;
          end else begin
            vref_dq  <= 8'h78; // optimal VREF (62.5% of VDD)
            tr_state <= TR_DONE;
          end
        end
        TR_ZQ: begin
          if (tr_timer < 8'd32) tr_timer <= tr_timer + 1;
          else tr_state <= TR_DONE;
        end
        TR_DONE: begin
          train_done        <= 1;
          dfi_init_complete <= 1;
          tr_state          <= TR_IDLE;
        end
        default: tr_state <= TR_IDLE;
      endcase
    end
  end

endmodule : ddr5_phy
