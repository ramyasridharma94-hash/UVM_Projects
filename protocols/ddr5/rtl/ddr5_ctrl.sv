// DDR5 Memory Controller — command scheduler, bank FSM, refresh engine
import ddr5_pkg::*;

module ddr5_ctrl #(
  parameter int NUM_BANKS  = 32,    // 8 bank groups × 4 banks
  parameter int NUM_BG     = 8,
  parameter int ROW_BITS   = 17,
  parameter int COL_BITS   = 10,
  parameter int DQ_WIDTH   = 32
)(
  input  logic              clk,
  input  logic              rst_n,
  // Host request interface
  input  logic              req_valid,
  input  ddr5_cmd_e         req_cmd,
  input  logic [2:0]        req_bg,
  input  logic [1:0]        req_bank,
  input  logic [ROW_BITS-1:0] req_row,
  input  logic [COL_BITS-1:0] req_col,
  input  logic [DQ_WIDTH*8-1:0] req_wdata,  // BL8 write data
  input  logic [DQ_WIDTH-1:0]   req_wmask,
  output logic              req_ready,
  // Read return
  output logic              rd_valid,
  output logic [DQ_WIDTH*8-1:0] rd_data,
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
  // Timing config
  input  ddr5_timing_t      timing,
  // Mode registers
  input  ddr5_mode_regs_t   mode_regs,
  // Error output
  output ddr5_error_e       err_type,
  output logic              err_valid,
  // Status
  output logic              init_done,
  output power_state_e      pwr_state
);

  // -----------------------------------------------------------------------
  // Per-bank state machine
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    BANK_IDLE, BANK_ACTIVATING, BANK_ACTIVE,
    BANK_PRECHARGING, BANK_REFRESHING, BANK_POWERDOWN
  } bank_state_e;

  bank_state_e             bank_state  [0:NUM_BANKS-1];
  logic [ROW_BITS-1:0]     open_row    [0:NUM_BANKS-1];
  logic [15:0]             bank_timer  [0:NUM_BANKS-1];
  logic [NUM_BANKS-1:0]    bank_busy;

  // -----------------------------------------------------------------------
  // Refresh engine
  // -----------------------------------------------------------------------
  logic [15:0]  ref_counter;
  logic         ref_req;
  logic [3:0]   ref_pending;  // burst refresh debt
  int unsigned  ref_interval;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ref_counter <= 0; ref_pending <= 0; ref_req <= 0;
    end else begin
      ref_interval = timing.tREFI;
      if (ref_counter >= ref_interval - 1) begin
        ref_counter  <= 0;
        ref_req      <= 1;
        ref_pending  <= ref_pending + 1;
      end else begin
        ref_counter <= ref_counter + 1;
        ref_req     <= 0;
      end
      if (ref_pending > 0 && !ref_req) ref_pending <= ref_pending - 1;
    end
  end

  // -----------------------------------------------------------------------
  // Initialization sequence
  // -----------------------------------------------------------------------
  typedef enum logic [3:0] {
    INIT_RESET, INIT_WAIT_200US, INIT_DESELECT, INIT_CKE_LOW, INIT_ZQCAL,
    INIT_MRS, INIT_DONE
  } init_state_e;

  init_state_e  init_state;
  logic [19:0]  init_timer;
  logic [3:0]   mrs_idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      init_state  <= INIT_RESET;
      init_timer  <= 0;
      mrs_idx     <= 0;
      dfi_reset_n <= 0;
      dfi_cke     <= 0;
      dfi_cs_n    <= 1;
      init_done   <= 0;
    end else begin
      case (init_state)
        INIT_RESET: begin
          dfi_reset_n <= 0; dfi_cke <= 0;
          if (init_timer >= 20'd200) begin  // 200µs @ typical clock
            init_state <= INIT_WAIT_200US; init_timer <= 0;
          end else init_timer <= init_timer + 1;
        end
        INIT_WAIT_200US: begin
          dfi_reset_n <= 1; dfi_cke <= 0;
          if (init_timer >= 20'd500) begin
            init_state <= INIT_CKE_LOW; init_timer <= 0;
          end else init_timer <= init_timer + 1;
        end
        INIT_CKE_LOW: begin
          dfi_cke <= 1;
          if (init_timer >= 20'd10) begin
            init_state <= INIT_ZQCAL; init_timer <= 0;
          end else init_timer <= init_timer + 1;
        end
        INIT_ZQCAL: begin
          // Issue ZQCAL_Long
          dfi_cs_n   <= 0;
          dfi_address <= 14'h0400;  // ZQCAL opcode
          if (init_timer >= 20'd(timing.tZQinit)) begin
            init_state <= INIT_MRS; init_timer <= 0; mrs_idx <= 0;
          end else begin dfi_cs_n <= 1; init_timer <= init_timer + 1; end
        end
        INIT_MRS: begin
          dfi_cs_n <= 0;
          // Issue MRS sequence: MR0, MR2, MR3, MR5, MR6, MR8, MR13, MR15
          case (mrs_idx)
            4'd0: dfi_address <= {6'h0,  mode_regs.mr0};
            4'd1: dfi_address <= {6'h2,  mode_regs.mr2};
            4'd2: dfi_address <= {6'h3,  mode_regs.mr3};
            4'd3: dfi_address <= {6'h5,  mode_regs.mr5};
            4'd4: dfi_address <= {6'h6,  mode_regs.mr6};
            4'd5: dfi_address <= {6'h8,  mode_regs.mr8};
            4'd6: dfi_address <= {6'hD,  mode_regs.mr13};
            4'd7: dfi_address <= {6'hF,  mode_regs.mr15};
            default: dfi_address <= 14'h0;
          endcase
          if (init_timer >= 20'd8) begin
            dfi_cs_n  <= 1;
            init_timer <= 0;
            mrs_idx   <= mrs_idx + 1;
            if (mrs_idx == 4'd7) init_state <= INIT_DONE;
          end else init_timer <= init_timer + 1;
        end
        INIT_DONE: begin
          dfi_cs_n  <= 1;
          init_done <= 1;
        end
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // Bank FSM — one instance per bank (flattened)
  // -----------------------------------------------------------------------
  genvar b;
  generate
    for (b = 0; b < NUM_BANKS; b++) begin : bank_fsm
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          bank_state[b] <= BANK_IDLE;
          bank_timer[b] <= 0;
          open_row[b]   <= '0;
          bank_busy[b]  <= 0;
        end else begin
          if (bank_timer[b] > 0) bank_timer[b] <= bank_timer[b] - 1;
          case (bank_state[b])
            BANK_IDLE: begin
              bank_busy[b] <= 0;
              if (init_done && req_valid &&
                  req_bg == 3'(b/4) && req_bank == 2'(b%4) &&
                  req_cmd == CMD_ACT && bank_timer[b] == 0) begin
                bank_state[b] <= BANK_ACTIVATING;
                bank_timer[b] <= 16'(timing.tRCD);
                open_row[b]   <= req_row;
                bank_busy[b]  <= 1;
              end
            end
            BANK_ACTIVATING: begin
              if (bank_timer[b] == 0) bank_state[b] <= BANK_ACTIVE;
            end
            BANK_ACTIVE: begin
              if (req_valid && req_bg == 3'(b/4) && req_bank == 2'(b%4)) begin
                case (req_cmd)
                  CMD_PRE, CMD_PREA: begin
                    bank_state[b] <= BANK_PRECHARGING;
                    bank_timer[b] <= 16'(timing.tRP);
                  end
                  CMD_RD, CMD_RDA, CMD_WR, CMD_WRA: begin
                    bank_busy[b] <= 0; // Granted
                  end
                  default: ;
                endcase
              end
              if (ref_req) begin
                bank_state[b] <= BANK_REFRESHING;
                bank_timer[b] <= 16'(timing.tRFC);
              end
            end
            BANK_PRECHARGING: begin
              if (bank_timer[b] == 0) bank_state[b] <= BANK_IDLE;
            end
            BANK_REFRESHING: begin
              if (bank_timer[b] == 0) bank_state[b] <= BANK_IDLE;
            end
            BANK_POWERDOWN: begin
              if (pwr_state == PWR_NORMAL) begin
                bank_state[b] <= BANK_IDLE;
                bank_timer[b] <= 16'(timing.tXP);
              end
            end
          endcase
        end
      end
    end
  endgenerate

  // -----------------------------------------------------------------------
  // Command issue / DFI drive
  // -----------------------------------------------------------------------
  logic [3:0]  rd_lat_cnt;
  logic        rd_pipe [0:47];  // pipe for read latency

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dfi_address   <= '0; dfi_bg <= '0; dfi_bank <= '0;
      dfi_cs_n      <= 1;  dfi_odt <= 0;
      dfi_wrdata    <= '0; dfi_wrmask <= '0; dfi_wrdata_en <= 0;
      rd_valid      <= 0;  rd_data <= '0;
      req_ready     <= 0;
      err_type      <= DDR5_ERR_NONE; err_valid <= 0;
      pwr_state     <= PWR_NORMAL;
      for (int i=0; i<48; i++) rd_pipe[i] <= 0;
    end else begin
      req_ready   <= 0; err_valid <= 0;
      dfi_cs_n    <= 1; dfi_wrdata_en <= 0;

      // Shift read pipe
      for (int i=1; i<48; i++) rd_pipe[i] <= rd_pipe[i-1];
      rd_pipe[0] <= 0;

      if (init_done && req_valid) begin
        int bk_idx = (int'(req_bg) * 4) + int'(req_bank);
        case (req_cmd)
          CMD_ACT: begin
            if (bank_state[bk_idx] == BANK_IDLE && bank_timer[bk_idx] == 0) begin
              dfi_cs_n   <= 0;
              dfi_address<= req_row[13:0];
              dfi_bg     <= req_bg;
              dfi_bank   <= req_bank;
              req_ready  <= 1;
            end
          end
          CMD_WR, CMD_WRA: begin
            if (bank_state[bk_idx] == BANK_ACTIVE) begin
              dfi_cs_n      <= 0;
              dfi_address   <= {4'h0, req_col};
              dfi_bg        <= req_bg; dfi_bank <= req_bank;
              dfi_wrdata    <= req_wdata;
              dfi_wrmask    <= req_wmask;
              dfi_wrdata_en <= 1;
              req_ready     <= 1;
            end
          end
          CMD_RD, CMD_RDA: begin
            if (bank_state[bk_idx] == BANK_ACTIVE) begin
              dfi_cs_n   <= 0;
              dfi_address<= {4'h0, req_col};
              dfi_bg     <= req_bg; dfi_bank <= req_bank;
              rd_pipe[0] <= 1;
              req_ready  <= 1;
            end
          end
          CMD_PRE: begin
            if (bank_state[bk_idx] == BANK_ACTIVE) begin
              dfi_cs_n   <= 0;
              dfi_address<= 14'h0;
              req_ready  <= 1;
            end
          end
          CMD_REF: begin
            dfi_cs_n   <= 0;
            dfi_address<= 14'h0001;
            req_ready  <= 1;
          end
          CMD_MRS: begin
            dfi_cs_n   <= 0;
            dfi_address<= req_row[13:0]; // MR addr in row field
            req_ready  <= 1;
          end
          CMD_PDE: begin
            pwr_state  <= PWR_PD;
            dfi_cs_n   <= 0; dfi_cke <= 0;
            req_ready  <= 1;
          end
          CMD_PDX: begin
            pwr_state  <= PWR_NORMAL;
            dfi_cke    <= 1;
            req_ready  <= 1;
          end
          CMD_SRE: begin
            pwr_state  <= PWR_SREF;
            dfi_cke    <= 0; dfi_cs_n <= 0;
            req_ready  <= 1;
          end
          CMD_SRX: begin
            pwr_state  <= PWR_NORMAL;
            dfi_cke    <= 1;
            req_ready  <= 1;
          end
          default: req_ready <= 1;
        endcase
      end

      // Read data return
      if (dfi_rddata_valid) begin
        rd_valid <= 1;
        rd_data  <= dfi_rddata;
      end else begin
        rd_valid <= 0;
      end

      // Alert: ECC or parity error
      if (!dfi_rddata_valid && rd_pipe[timing.tCL-1]) begin
        err_type  <= DDR5_ERR_TIMING_VIOL;
        err_valid <= 1;
      end
    end
  end

endmodule : ddr5_ctrl
