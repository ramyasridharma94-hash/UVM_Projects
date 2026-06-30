// DDR5 Mode Register Controller
// Handles runtime MRS updates (without full re-init), MRR reads,
// and maintains a shadow copy of all mode registers
import ddr5_pkg::*;

module ddr5_mode_reg_ctrl (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              init_done,
  // Software MRS request (from APB config slave)
  input  logic              mrs_req,
  input  logic [7:0]        mrs_mr_addr,
  input  logic [7:0]        mrs_mr_data,
  output logic              mrs_ack,
  // Software MRR request
  input  logic              mrr_req,
  input  logic [7:0]        mrr_mr_addr,
  output logic [7:0]        mrr_rd_data,
  output logic              mrr_valid,
  // DFI command interface
  output logic              cmd_valid,
  output ddr5_cmd_e         cmd_out,
  output logic [13:0]       cmd_addr,
  input  logic              cmd_ready,
  // DQ read data (MRR response — captured by DFI ctrl)
  input  logic [7:0]        dfi_mrr_data,
  input  logic              dfi_mrr_valid,
  // Shadow mode registers (read by rest of controller)
  output ddr5_mode_regs_t   shadow_mrs,
  // Status
  output logic              busy
);

  typedef enum logic [2:0] {
    MRC_IDLE, MRC_MRS_ISSUE, MRC_MRS_WAIT,
    MRC_MRR_ISSUE, MRC_MRR_WAIT, MRC_MRR_CAPTURE
  } mrc_state_e;

  mrc_state_e state;
  logic [7:0]  pending_addr, pending_data;
  logic [7:0]  tmrd_cnt;      // tMRD counter

  assign busy = (state != MRC_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= MRC_IDLE;
      cmd_valid   <= 0; cmd_out <= CMD_NOP; cmd_addr <= '0;
      mrs_ack     <= 0; mrr_valid <= 0; mrr_rd_data <= '0;
      tmrd_cnt    <= '0;
      // Initialise shadow registers with JEDEC defaults
      shadow_mrs  <= '{
        mr0:  8'h14, mr2:  8'h00, mr3:  8'h01, mr4:  8'h00,
        mr5:  8'hCC, mr6:  8'h04, mr7:  8'h04, mr8:  8'h40,
        mr10: 8'h04, mr11: 8'h04, mr13: 8'h04, mr15: 8'h01,
        mr17: 8'h04, mr24: 8'h00, mr28: 8'h00
      };
    end else begin
      cmd_valid <= 0; mrs_ack <= 0; mrr_valid <= 0;
      if (tmrd_cnt > 0) tmrd_cnt <= tmrd_cnt - 1;

      case (state)
        MRC_IDLE: begin
          if (init_done && mrs_req && !busy) begin
            pending_addr <= mrs_mr_addr;
            pending_data <= mrs_mr_data;
            state        <= MRC_MRS_ISSUE;
          end else if (init_done && mrr_req && !busy) begin
            pending_addr <= mrr_mr_addr;
            state        <= MRC_MRR_ISSUE;
          end
        end

        // -------------------------------------------------------
        MRC_MRS_ISSUE: begin
          if (tmrd_cnt == 0) begin
            cmd_valid <= 1;
            cmd_out   <= CMD_MRS;
            // Cycle 1: MR address
            cmd_addr  <= {6'b000100, pending_addr};
            if (cmd_ready) begin
              // Cycle 2: MR data
              cmd_addr  <= {6'h00, pending_data};
              state     <= MRC_MRS_WAIT;
              tmrd_cnt  <= 8'd8;  // tMRD = 8 nCK
            end
          end
        end

        MRC_MRS_WAIT: begin
          cmd_valid <= 0;
          if (tmrd_cnt == 0) begin
            // Update shadow register
            case (pending_addr)
              8'd0:  shadow_mrs.mr0  <= pending_data;
              8'd2:  shadow_mrs.mr2  <= pending_data;
              8'd3:  shadow_mrs.mr3  <= pending_data;
              8'd4:  shadow_mrs.mr4  <= pending_data;
              8'd5:  shadow_mrs.mr5  <= pending_data;
              8'd6:  shadow_mrs.mr6  <= pending_data;
              8'd7:  shadow_mrs.mr7  <= pending_data;
              8'd8:  shadow_mrs.mr8  <= pending_data;
              8'd10: shadow_mrs.mr10 <= pending_data;
              8'd11: shadow_mrs.mr11 <= pending_data;
              8'd13: shadow_mrs.mr13 <= pending_data;
              8'd15: shadow_mrs.mr15 <= pending_data;
              8'd17: shadow_mrs.mr17 <= pending_data;
              8'd24: shadow_mrs.mr24 <= pending_data;
              8'd28: shadow_mrs.mr28 <= pending_data;
              default: ;
            endcase
            mrs_ack <= 1;
            state   <= MRC_IDLE;
          end
        end

        // -------------------------------------------------------
        MRC_MRR_ISSUE: begin
          cmd_valid <= 1;
          cmd_out   <= CMD_MRR;
          cmd_addr  <= {6'b000010, pending_addr};
          if (cmd_ready) begin
            cmd_valid <= 0;
            state     <= MRC_MRR_WAIT;
          end
        end

        MRC_MRR_WAIT: begin
          // Wait for DFI MRR data to come back (after tMRR latency)
          if (dfi_mrr_valid) begin
            mrr_rd_data <= dfi_mrr_data;
            mrr_valid   <= 1;
            state       <= MRC_IDLE;
          end
        end

        default: state <= MRC_IDLE;
      endcase
    end
  end

endmodule : ddr5_mode_reg_ctrl
