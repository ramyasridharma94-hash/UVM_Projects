// DDR5 Initialization FSM — JEDEC DDR5 (JESD79-5B) compliant power-up sequence
// Sequence: RESET_n → CKE toggle → ZQ_Long → MRS×N → Refresh
// All timed waits use clock cycles derived from timing struct
import ddr5_pkg::*;

module ddr5_init_fsm #(
  parameter int CLK_FREQ_MHZ = 200,   // DFI reference clock frequency
  parameter int NUM_MR       = 11     // Number of MRS commands to issue
)(
  input  logic              clk,
  input  logic              rst_n,
  // Trigger
  input  logic              start,
  // Timing parameters
  input  ddr5_timing_t      timing,
  // Mode registers to program
  input  ddr5_mode_regs_t   mode_regs,
  // DFI command output
  output logic              cmd_valid,
  output ddr5_cmd_e         cmd_out,
  output logic [13:0]       cmd_addr,
  output logic              cmd_cke,
  output logic              cmd_cs_n,
  output logic              cmd_reset_n,
  input  logic              cmd_ready,
  // Done
  output logic              init_done,
  // Debug
  output logic [3:0]        init_state_out
);

  typedef enum logic [3:0] {
    S_IDLE          = 4'h0,
    S_RESET_ASSERT  = 4'h1,   // Assert RESET_n low for 200 µs min
    S_RESET_DEASSERT= 4'h2,   // Deassert RESET_n, CKE=0, 500 µs
    S_CKE_LOW       = 4'h3,   // CKE stable low, tINIT4 = 5 ns
    S_CKE_HIGH      = 4'h4,   // CKE goes high, wait tCKE (≥2 clocks)
    S_ZQCAL_START   = 4'h5,   // ZQCAL_Long start (tZQinit cycles)
    S_ZQCAL_WAIT    = 4'h6,
    S_ZQCAL_LATCH   = 4'h7,
    S_MRS           = 4'h8,   // Mode register programming
    S_MRS_WAIT      = 4'h9,   // tMRD wait between MRS commands
    S_POST_REF      = 4'hA,   // Issue 2 All-Bank Refresh
    S_POST_REF_WAIT = 4'hB,
    S_DONE          = 4'hF
  } init_state_e;

  init_state_e state;
  logic [23:0]  timer;         // 24-bit = up to 16M cycles (~83ms @ 200MHz)
  logic [3:0]   mrs_idx;       // Which MR is being programmed
  logic [23:0]  wait_target;
  logic [1:0]   ref_cnt;

  // Timing constants in clock cycles (at CLK_FREQ_MHZ)
  // tINIT1 (RESET_n low) = 200 µs = 200*CLK_FREQ_MHZ/1000 cycles
  localparam int TINIT1_CYCLES = (200 * CLK_FREQ_MHZ) / 1000;   // 40K @ 200MHz
  // tINIT3 (CKE low after RESET_n high) = 500 µs
  localparam int TINIT3_CYCLES = (500 * CLK_FREQ_MHZ) / 1000;   // 100K @ 200MHz
  // tINIT4 (RESET_n de-asserted to CKE high) = 5 ns
  localparam int TINIT4_CYCLES = 4;
  // tCKE = 3 ns = ceil(3*CLK_FREQ_MHZ/1000)
  localparam int TCKE_CYCLES   = 4;
  // tMRD = 8 ns = max(8nCK, 8ns)
  localparam int TMRD_CYCLES   = 8;

  // MR sequence: {mr_addr[7:0], mr_data[7:0]} packed
  typedef struct packed { logic [7:0] addr; logic [7:0] data; } mr_prog_t;
  mr_prog_t mrs_seq [0:10];

  // -----------------------------------------------------------------------
  assign init_state_out = 4'(state);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      timer      <= '0; wait_target <= '0;
      mrs_idx    <= '0; ref_cnt <= '0;
      cmd_valid  <= 0;  cmd_out <= CMD_NOP;
      cmd_addr   <= '0; cmd_cke <= 0; cmd_cs_n <= 1; cmd_reset_n <= 0;
      init_done  <= 0;
      // Initialise MRS sequence
      mrs_seq[0]  <= '{8'd0,  8'h14};  // MR0:  BL=BL8, CL=20
      mrs_seq[1]  <= '{8'd2,  8'h00};  // MR2:  Write Leveling off
      mrs_seq[2]  <= '{8'd3,  8'h01};  // MR3:  Gear-Down
      mrs_seq[3]  <= '{8'd5,  8'hCC};  // MR5:  CA ODT / CS ODT
      mrs_seq[4]  <= '{8'd6,  8'h04};  // MR6:  RTT_NOM_WR = RZQ/4
      mrs_seq[5]  <= '{8'd7,  8'h04};  // MR7:  RTT_NOM_RD = RZQ/4
      mrs_seq[6]  <= '{8'd8,  8'h40};  // MR8:  VREF DQ training enabled
      mrs_seq[7]  <= '{8'd10, 8'h04};  // MR10: ODT write timing
      mrs_seq[8]  <= '{8'd13, 8'h04};  // MR13: CA parity enable
      mrs_seq[9]  <= '{8'd15, 8'h01};  // MR15: ECC SEC/DED enable
      mrs_seq[10] <= '{8'd17, 8'h04};  // MR17: DQ driver impedance
    end else begin
      // Update MRS data from mode_regs input (dynamic binding)
      mrs_seq[0].data  <= mode_regs.mr0;
      mrs_seq[1].data  <= mode_regs.mr2;
      mrs_seq[2].data  <= mode_regs.mr3;
      mrs_seq[3].data  <= mode_regs.mr5;
      mrs_seq[4].data  <= mode_regs.mr6;
      mrs_seq[5].data  <= mode_regs.mr7;
      mrs_seq[6].data  <= mode_regs.mr8;
      mrs_seq[7].data  <= mode_regs.mr10;
      mrs_seq[8].data  <= mode_regs.mr13;
      mrs_seq[9].data  <= mode_regs.mr15;
      mrs_seq[10].data <= mode_regs.mr17;

      if (timer > 0) timer <= timer - 1;
      cmd_valid <= 0;

      case (state)
        // -------------------------------------------------------
        S_IDLE: begin
          cmd_cke <= 0; cmd_cs_n <= 1; cmd_reset_n <= 0;
          init_done <= 0;
          if (start) begin
            state <= S_RESET_ASSERT;
            timer <= 24'(TINIT1_CYCLES);
          end
        end

        // -------------------------------------------------------
        S_RESET_ASSERT: begin
          // RESET_n = 0, CKE = 0, CK running
          cmd_reset_n <= 0; cmd_cke <= 0; cmd_cs_n <= 1;
          if (timer == 0) begin
            state       <= S_RESET_DEASSERT;
            timer       <= 24'(TINIT3_CYCLES);
            cmd_reset_n <= 1;  // Release RESET_n
          end
        end

        // -------------------------------------------------------
        S_RESET_DEASSERT: begin
          // RESET_n = 1, CKE = 0 for tINIT3
          cmd_reset_n <= 1; cmd_cke <= 0;
          if (timer == 0) begin
            state <= S_CKE_LOW;
            timer <= 24'(TINIT4_CYCLES);
          end
        end

        // -------------------------------------------------------
        S_CKE_LOW: begin
          cmd_cke <= 0;
          if (timer == 0) begin
            state <= S_CKE_HIGH;
            timer <= 24'(TCKE_CYCLES);
            cmd_cke <= 1;  // CKE goes high
          end
        end

        // -------------------------------------------------------
        S_CKE_HIGH: begin
          cmd_cke <= 1; cmd_cs_n <= 1;  // NOP period
          if (timer == 0) begin
            state <= S_ZQCAL_START;
          end
        end

        // -------------------------------------------------------
        S_ZQCAL_START: begin
          // Issue ZQ Calibration Long (tZQinit = 1024 nCK)
          cmd_valid <= 1;
          cmd_out   <= CMD_ZQCAL;
          cmd_addr  <= 14'h0400;   // ZQCAL opcode
          cmd_cs_n  <= 0;
          if (cmd_ready) begin
            cmd_valid <= 0; cmd_cs_n <= 1;
            state     <= S_ZQCAL_WAIT;
            timer     <= 24'(timing.tZQinit);
          end
        end

        // -------------------------------------------------------
        S_ZQCAL_WAIT: begin
          if (timer == 0) begin
            state     <= S_ZQCAL_LATCH;
            cmd_valid <= 1;
            cmd_out   <= CMD_ZQLAT;
            cmd_addr  <= 14'h0200;
            cmd_cs_n  <= 0;
          end
        end

        // -------------------------------------------------------
        S_ZQCAL_LATCH: begin
          if (cmd_ready) begin
            cmd_valid <= 0; cmd_cs_n <= 1;
            state     <= S_MRS;
            mrs_idx   <= 0;
            timer     <= 24'(TMRD_CYCLES);
          end
        end

        // -------------------------------------------------------
        S_MRS: begin
          // Issue MRS for current mrs_idx
          if (timer == 0) begin
            cmd_valid <= 1;
            cmd_out   <= CMD_MRS;
            cmd_cs_n  <= 0;
            // DDR5 MRS encoding: CA[7:0] = MR_addr, CA[13:8] = opcode
            cmd_addr  <= {6'b000100, mrs_seq[mrs_idx].addr};
            if (cmd_ready) begin
              // Second cycle: data
              cmd_addr  <= {6'b000000, mrs_seq[mrs_idx].data};
              state     <= S_MRS_WAIT;
              timer     <= 24'(TMRD_CYCLES);
            end
          end
        end

        // -------------------------------------------------------
        S_MRS_WAIT: begin
          cmd_valid <= 0; cmd_cs_n <= 1;
          if (timer == 0) begin
            mrs_idx <= mrs_idx + 1;
            if (mrs_idx + 1 >= NUM_MR) begin
              state   <= S_POST_REF;
              ref_cnt <= 0;
            end else begin
              state <= S_MRS;
            end
          end
        end

        // -------------------------------------------------------
        S_POST_REF: begin
          // Issue 2× All-Bank Refresh after MRS programming
          cmd_valid <= 1;
          cmd_out   <= CMD_REF;
          cmd_addr  <= 14'h0001;
          cmd_cs_n  <= 0;
          if (cmd_ready) begin
            cmd_valid <= 0; cmd_cs_n <= 1;
            state     <= S_POST_REF_WAIT;
            timer     <= 24'(timing.tRFC);
          end
        end

        // -------------------------------------------------------
        S_POST_REF_WAIT: begin
          if (timer == 0) begin
            ref_cnt <= ref_cnt + 1;
            if (ref_cnt >= 2'd1) begin
              state <= S_DONE;
            end else begin
              state <= S_POST_REF;
            end
          end
        end

        // -------------------------------------------------------
        S_DONE: begin
          init_done <= 1;
          cmd_cs_n  <= 1;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule : ddr5_init_fsm
