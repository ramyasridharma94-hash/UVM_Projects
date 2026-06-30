// PCIe Transaction Layer — TLP Transmitter
// Handles MRd/MWr/IO/Cfg/Msg/Cpl/AtomicOp TLPs, ECRC generation, FC gating
import pcie_pkg::*;

module pcie_tlp_tx (
  input  logic              clk,
  input  logic              rst_n,
  // Application request interface
  input  logic              req_valid,
  input  tlp_type_e         req_tlp_type,
  input  logic [63:0]       req_addr,
  input  logic [9:0]        req_length,      // in DWs
  input  logic [2:0]        req_tc,          // traffic class
  input  logic [1:0]        req_attr,        // relaxed ordering, no-snoop
  input  logic [15:0]       req_req_id,      // requester ID {bus,dev,fn}
  input  logic [7:0]        req_tag,         // extended tag (10b supported)
  input  logic [3:0]        req_first_be,
  input  logic [3:0]        req_last_be,
  input  logic [2:0]        req_msg_code,    // for Message TLPs
  input  logic              req_ep,          // error poisoned
  input  logic              req_ecrc_en,     // generate ECRC
  input  logic [63:0]       req_data_lo,     // first 2 DWs of payload
  input  logic [63:0]       req_data_hi,
  output logic              req_ready,
  // DLL interface
  output logic              tlp_valid,
  output logic [255:0]      tlp_data,        // packed TLP (up to 8DW)
  output logic [2:0]        tlp_len_dw,
  input  logic              tlp_ready,
  // Flow control (from remote)
  input  fc_credits_t       fc_posted,
  input  fc_credits_t       fc_non_posted,
  input  fc_credits_t       fc_completion,
  // Status
  output logic              tlp_sent,
  output logic [7:0]        tlp_tag_out,
  output pcie_error_e       tlp_error
);

  // ECRC calculation (CRC-32)
  function automatic logic [31:0] calc_crc32(input logic [255:0] data, input int bytes);
    logic [31:0] crc = 32'hFFFF_FFFF;
    for (int i = 0; i < bytes*8; i++) begin
      logic b = data[i] ^ crc[31];
      crc = {crc[30:0], 1'b0};
      if (b) crc ^= 32'h04C1_1DB7;
    end
    return ~crc;
  endfunction

  // Build 3DW header (no address extension)
  function automatic logic [95:0] build_3dw_hdr(
    input tlp_type_e typ,
    input logic [9:0] len,
    input logic [2:0] tc,
    input logic [1:0] attr,
    input logic [15:0] req_id,
    input logic [7:0]  tag,
    input logic [3:0]  first_be,
    input logic [3:0]  last_be,
    input logic [31:0] addr32,
    input logic        ep,
    input logic        td
  );
    logic [7:0] fmt_type;
    fmt_type = 8'(typ);
    return {fmt_type, 1'b0, tc, 4'b0, 1'b0, 1'b0, td, ep, attr, 2'b0, len,
            req_id, tag, last_be, first_be,
            addr32[31:2], 2'b0};
  endfunction

  // Build 4DW header
  function automatic logic [127:0] build_4dw_hdr(
    input tlp_type_e typ,
    input logic [9:0] len,
    input logic [2:0] tc,
    input logic [1:0] attr,
    input logic [15:0] req_id,
    input logic [7:0]  tag,
    input logic [3:0]  first_be,
    input logic [3:0]  last_be,
    input logic [63:0] addr64,
    input logic        ep,
    input logic        td
  );
    logic [7:0] fmt_type;
    fmt_type = 8'(typ);
    return {fmt_type, 1'b0, tc, 4'b0, 1'b0, 1'b0, td, ep, attr, 2'b0, len,
            req_id, tag, last_be, first_be,
            addr64[63:2], 2'b0};
  endfunction

  // -------------------------------------------------------------------------
  // FC gating: determine which pool to check
  // -------------------------------------------------------------------------
  function automatic logic fc_ok(input tlp_type_e typ,
                                  input fc_credits_t posted,
                                  input fc_credits_t nposted,
                                  input fc_credits_t cpl);
    case (typ)
      MWr32, MWr64, MsgD, Msg:
        return (posted.hdr_credits  > 0 && posted.data_credits > 0);
      MRd32, MRd64, IORd, IOWr, CfgRd0, CfgRd1, CfgWr0, CfgWr1,
      FetchAdd32, FetchAdd64, Swap32, Swap64, CAS32, CAS64:
        return (nposted.hdr_credits > 0 && nposted.data_credits > 0);
      CplD, Cpl, CplDLk, CplLk:
        return (cpl.hdr_credits     > 0 && cpl.data_credits > 0);
      default: return 1;
    endcase
  endfunction

  // -------------------------------------------------------------------------
  // TLP assembly state machine
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] { IDLE, BUILD, SEND, DONE } tx_state_e;
  tx_state_e tx_state;

  logic [255:0] tlp_reg;
  logic [2:0]   tlp_dw_cnt;
  logic [31:0]  ecrc_val;
  logic         is_4dw;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state   <= IDLE;
      tlp_valid  <= 0;
      tlp_data   <= '0;
      tlp_len_dw <= '0;
      req_ready  <= 0;
      tlp_sent   <= 0;
      tlp_error  <= ERR_NONE;
      tlp_tag_out<= '0;
    end else begin
      tlp_sent  <= 0;
      req_ready <= 0;
      case (tx_state)
        IDLE: begin
          if (req_valid && fc_ok(req_tlp_type, fc_posted, fc_non_posted, fc_completion)) begin
            req_ready <= 1;
            tx_state  <= BUILD;
          end
        end
        BUILD: begin
          tlp_tag_out <= req_tag;
          is_4dw      <= (req_addr[63:32] != 32'h0) ||
                         req_tlp_type inside {MRd64, MWr64, FetchAdd64, Swap64, CAS64};
          // Assemble header + first 2 DWs of payload
          if (!is_4dw) begin
            logic [95:0]  hdr3;
            hdr3 = build_3dw_hdr(req_tlp_type, req_length, req_tc, req_attr,
                                   req_req_id, req_tag, req_first_be, req_last_be,
                                   req_addr[31:0], req_ep,
                                   req_ecrc_en);
            tlp_reg    <= {req_data_hi, req_data_lo, 32'h0, hdr3};
            tlp_dw_cnt <= (req_length == 0) ? 3'd3 : 3'(req_length + 3);
          end else begin
            logic [127:0] hdr4;
            hdr4 = build_4dw_hdr(req_tlp_type, req_length, req_tc, req_attr,
                                   req_req_id, req_tag, req_first_be, req_last_be,
                                   req_addr, req_ep,
                                   req_ecrc_en);
            tlp_reg    <= {req_data_lo, hdr4};
            tlp_dw_cnt <= (req_length == 0) ? 3'd4 : 3'(req_length + 4);
          end
          if (req_ecrc_en) begin
            ecrc_val   <= calc_crc32(tlp_reg, 32);
            tlp_dw_cnt <= tlp_dw_cnt + 1;
          end
          tx_state <= SEND;
        end
        SEND: begin
          if (tlp_ready || !tlp_valid) begin
            // Append ECRC if enabled
            if (req_ecrc_en)
              tlp_reg[255:224] <= ecrc_val;
            tlp_data   <= tlp_reg;
            tlp_len_dw <= tlp_dw_cnt;
            tlp_valid  <= 1;
            tx_state   <= DONE;
          end
        end
        DONE: begin
          if (tlp_ready) begin
            tlp_valid <= 0;
            tlp_sent  <= 1;
            tx_state  <= IDLE;
          end
        end
      endcase
    end
  end

endmodule : pcie_tlp_tx
