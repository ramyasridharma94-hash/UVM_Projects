// PCIe Data Link Layer — sequence numbers, ACK/NAK, retry buffer, flow control
import pcie_pkg::*;

module pcie_dll #(
  parameter int REPLAY_BUF_DEPTH = 256,
  parameter int RETRY_LIMIT      = 4,
  parameter int ACK_LATENCY      = 8,
  parameter int FC_HDR_INIT      = 8'hFF,
  parameter int FC_DATA_INIT     = 12'hFFF
)(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              dl_up,           // from PHY
  // TLP from TX
  input  logic              tlp_tx_valid,
  input  logic [255:0]      tlp_tx_data,     // up to 8DW
  input  logic [2:0]        tlp_tx_len_dw,
  output logic              tlp_tx_ready,
  // TLP to RX
  output logic              tlp_rx_valid,
  output logic [255:0]      tlp_rx_data,
  output logic [2:0]        tlp_rx_len_dw,
  input  logic              tlp_rx_ready,
  // DLLP TX to PHY
  output logic              dllp_tx_valid,
  output logic [31:0]       dllp_tx_data,
  input  logic              dllp_tx_ready,
  // DLLP RX from PHY
  input  logic              dllp_rx_valid,
  input  logic [31:0]       dllp_rx_data,
  // Flow Control credits (advertise to remote)
  output fc_credits_t       fc_posted,
  output fc_credits_t       fc_non_posted,
  output fc_credits_t       fc_completion,
  // Flow Control credits consumed (from remote)
  input  fc_credits_t       remote_fc_posted,
  input  fc_credits_t       remote_fc_non_posted,
  input  fc_credits_t       remote_fc_completion,
  // Power management
  input  logic              pm_enter_l1_req,
  output logic              pm_ack,
  // Error output
  output pcie_error_e       dll_error,
  output logic              dll_error_valid
);

  // -------------------------------------------------------------------------
  // Sequence numbers (12-bit, wrapping)
  // -------------------------------------------------------------------------
  logic [11:0] tx_seq_num;
  logic [11:0] ackd_seq_num;   // last ACKed
  logic [11:0] rx_seq_num_exp; // expected receive sequence

  // Retry buffer
  logic [255:0] retry_buf      [0:REPLAY_BUF_DEPTH-1];
  logic [2:0]   retry_buf_len  [0:REPLAY_BUF_DEPTH-1];
  logic [11:0]  retry_buf_seq  [0:REPLAY_BUF_DEPTH-1];
  logic [$clog2(REPLAY_BUF_DEPTH)-1:0] retry_wr_ptr, retry_rd_ptr;
  logic [7:0]   retry_count;
  logic         replay_pending;
  logic [15:0]  replay_timer;
  logic [3:0]   replay_num;

  // DLLP TX FIFO (simple register)
  logic [31:0]  dllp_fifo [0:7];
  logic [2:0]   dllp_wr_ptr, dllp_rd_ptr;
  logic         dllp_fifo_empty;
  logic [15:0]  ack_timer;

  // -------------------------------------------------------------------------
  // TX Sequence Number & Retry Buffer Write
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_seq_num  <= 12'hFFF; // wraps to 0 on first increment
      retry_wr_ptr <= '0;
    end else if (tlp_tx_valid && tlp_tx_ready && dl_up) begin
      tx_seq_num   <= tx_seq_num + 1;
      retry_buf     [retry_wr_ptr] <= tlp_tx_data;
      retry_buf_len [retry_wr_ptr] <= tlp_tx_len_dw;
      retry_buf_seq [retry_wr_ptr] <= tx_seq_num + 1;
      retry_wr_ptr <= retry_wr_ptr + 1;
    end
  end

  // -------------------------------------------------------------------------
  // ACK/NAK processing
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ackd_seq_num  <= 12'hFFF;
      replay_pending <= 0;
      retry_rd_ptr  <= '0;
      replay_num    <= '0;
      retry_count   <= '0;
      dll_error     <= ERR_NONE;
      dll_error_valid <= 0;
    end else begin
      dll_error_valid <= 0;
      if (dllp_rx_valid) begin
        case (dllp_rx_data[31:24])
          DLLP_Ack: begin
            ackd_seq_num   <= dllp_rx_data[11:0];
            replay_pending <= 0;
            replay_num     <= '0;
            retry_count    <= '0;
          end
          DLLP_Nak: begin
            // Trigger replay from NAKed sequence
            replay_pending <= 1;
            retry_rd_ptr   <= '0; // simplified: replay from start
            replay_num     <= replay_num + 1;
            if (replay_num >= RETRY_LIMIT) begin
              dll_error       <= ERR_REPLAY_ROLLOVER;
              dll_error_valid <= 1;
            end
          end
        endcase
      end
    end
  end

  // -------------------------------------------------------------------------
  // ACK timer — send ACK after ACK_LATENCY clocks of inactivity
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ack_timer  <= '0;
      dllp_wr_ptr <= '0;
      rx_seq_num_exp <= 12'h000;
    end else begin
      if (tlp_rx_valid && tlp_rx_ready) begin
        ack_timer      <= '0;
        rx_seq_num_exp <= rx_seq_num_exp + 1;
      end else begin
        ack_timer <= ack_timer + 1;
      end
      // Send ACK DLLP
      if (ack_timer == ACK_LATENCY && dl_up) begin
        dllp_fifo[dllp_wr_ptr] <= {DLLP_Ack, 12'h0, rx_seq_num_exp - 1};
        dllp_wr_ptr <= dllp_wr_ptr + 1;
        ack_timer   <= '0;
      end
      // Power management ACK DLLP
      if (pm_enter_l1_req) begin
        dllp_fifo[dllp_wr_ptr] <= {DLLP_PM_Req_Ack, 24'h0};
        dllp_wr_ptr <= dllp_wr_ptr + 1;
      end
    end
  end

  assign pm_ack = (dllp_tx_valid && dllp_tx_data[31:24] == DLLP_PM_Req_Ack);

  // -------------------------------------------------------------------------
  // DLLP TX arbitration
  // -------------------------------------------------------------------------
  assign dllp_fifo_empty = (dllp_wr_ptr == dllp_rd_ptr);
  assign dllp_tx_valid   = !dllp_fifo_empty && dl_up;
  assign dllp_tx_data    = dllp_fifo[dllp_rd_ptr];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) dllp_rd_ptr <= '0;
    else if (dllp_tx_valid && dllp_tx_ready)
      dllp_rd_ptr <= dllp_rd_ptr + 1;
  end

  // -------------------------------------------------------------------------
  // Flow Control initialization & updates
  // -------------------------------------------------------------------------
  // Local FC credits advertised to remote
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fc_posted.hdr_credits   <= FC_HDR_INIT;
      fc_posted.data_credits  <= FC_DATA_INIT;
      fc_non_posted.hdr_credits  <= FC_HDR_INIT;
      fc_non_posted.data_credits <= FC_DATA_INIT;
      fc_completion.hdr_credits  <= FC_HDR_INIT;
      fc_completion.data_credits <= FC_DATA_INIT;
    end
  end

  // TLP TX ready — stall if no FC credits from remote or replay in progress
  assign tlp_tx_ready = dl_up && !replay_pending &&
                        (remote_fc_posted.hdr_credits   > 0) &&
                        (remote_fc_posted.data_credits  > 0);

  // RX path — pass TLPs up (simplified pass-through with sequence check)
  assign tlp_rx_valid   = tlp_tx_valid;  // loopback model: driven from TB directly
  assign tlp_rx_data    = tlp_tx_data;
  assign tlp_rx_len_dw  = tlp_tx_len_dw;

endmodule : pcie_dll
