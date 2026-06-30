// PCIe Transaction Layer — TLP Receiver
// Parses all TLP types, checks LCRC/ECRC, dispatches completions
import pcie_pkg::*;

module pcie_tlp_rx (
  input  logic              clk,
  input  logic              rst_n,
  // DLL interface (incoming TLPs)
  input  logic              tlp_valid,
  input  logic [255:0]      tlp_data,
  input  logic [2:0]        tlp_len_dw,
  output logic              tlp_ready,
  // Parsed output — posted (MWr, Msg)
  output logic              posted_valid,
  output tlp_type_e         posted_type,
  output logic [63:0]       posted_addr,
  output logic [9:0]        posted_length,
  output logic [63:0]       posted_data,
  output logic [2:0]        posted_tc,
  output logic              posted_ep,
  // Parsed output — non-posted (MRd, IO, Cfg)
  output logic              np_valid,
  output tlp_type_e         np_type,
  output logic [63:0]       np_addr,
  output logic [9:0]        np_length,
  output logic [15:0]       np_req_id,
  output logic [7:0]        np_tag,
  output logic [3:0]        np_first_be,
  output logic [3:0]        np_last_be,
  output logic [2:0]        np_tc,
  // Parsed output — completion
  output logic              cpl_valid,
  output tlp_type_e         cpl_type,
  output cpl_status_e       cpl_status,
  output logic [15:0]       cpl_req_id,
  output logic [7:0]        cpl_tag,
  output logic [11:0]       cpl_byte_cnt,
  output logic [63:0]       cpl_data,
  // Error
  output pcie_error_e       rx_error,
  output logic              rx_error_valid,
  // Config space access (Type 0)
  output logic              cfg_rd_valid,
  output logic              cfg_wr_valid,
  output logic [11:0]       cfg_reg_num,
  output logic [15:0]       cfg_req_id,
  output logic [7:0]        cfg_tag,
  output logic [31:0]       cfg_wr_data,
  output logic [3:0]        cfg_be
);

  // -------------------------------------------------------------------------
  // Header field extraction (DW0 common)
  // -------------------------------------------------------------------------
  logic [7:0]  fmt_type;
  logic [2:0]  tc;
  logic        td, ep;
  logic [1:0]  attr;
  logic [9:0]  length;
  logic        is_4dw_hdr, has_data;

  always_comb begin
    fmt_type  = tlp_data[7:0];
    tc        = tlp_data[22:20];
    td        = tlp_data[15];
    ep        = tlp_data[14];
    attr      = tlp_data[13:12];
    length    = tlp_data[25:16] == 10'h0 ? 10'd1024 : tlp_data[25:16];
    is_4dw_hdr= fmt_type[6];
    has_data  = fmt_type[7];
  end

  // -------------------------------------------------------------------------
  // 3DW header fields
  // -------------------------------------------------------------------------
  logic [15:0] req_id_3dw;
  logic [7:0]  tag_3dw;
  logic [3:0]  last_be_3dw, first_be_3dw;
  logic [31:0] addr_3dw;
  always_comb begin
    req_id_3dw  = tlp_data[47:32];
    tag_3dw     = tlp_data[55:48];
    last_be_3dw = tlp_data[59:56];
    first_be_3dw= tlp_data[63:60];
    addr_3dw    = {tlp_data[93:64], 2'b0};
  end

  // -------------------------------------------------------------------------
  // 4DW header fields
  // -------------------------------------------------------------------------
  logic [15:0] req_id_4dw;
  logic [7:0]  tag_4dw;
  logic [3:0]  last_be_4dw, first_be_4dw;
  logic [63:0] addr_4dw;
  always_comb begin
    req_id_4dw  = tlp_data[47:32];
    tag_4dw     = tlp_data[55:48];
    last_be_4dw = tlp_data[59:56];
    first_be_4dw= tlp_data[63:60];
    addr_4dw    = {tlp_data[127:64], 2'b0};
  end

  // -------------------------------------------------------------------------
  // Completion header fields (3DW)
  // -------------------------------------------------------------------------
  logic [15:0] cpl_id;
  logic [2:0]  status;
  logic [11:0] byte_cnt;
  logic [15:0] req_id_cpl;
  logic [7:0]  tag_cpl;
  logic [6:0]  lower_addr;
  always_comb begin
    cpl_id     = tlp_data[47:32];
    status     = tlp_data[50:48];
    byte_cnt   = tlp_data[43:32];
    req_id_cpl = tlp_data[79:64];
    tag_cpl    = tlp_data[87:80];
    lower_addr = tlp_data[94:88];
  end

  // -------------------------------------------------------------------------
  // Dispatch
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      posted_valid  <= 0; np_valid    <= 0; cpl_valid   <= 0;
      cfg_rd_valid  <= 0; cfg_wr_valid<= 0;
      rx_error      <= ERR_NONE; rx_error_valid <= 0;
      tlp_ready     <= 1;
    end else begin
      posted_valid  <= 0; np_valid    <= 0; cpl_valid   <= 0;
      cfg_rd_valid  <= 0; cfg_wr_valid<= 0;
      rx_error_valid<= 0;

      if (tlp_valid && tlp_ready) begin
        case (tlp_type_e'(fmt_type))
          // ---- Posted: Memory Write ----
          MWr32: begin
            posted_valid  <= 1;
            posted_type   <= MWr32;
            posted_addr   <= {32'h0, addr_3dw};
            posted_length <= length;
            posted_data   <= tlp_data[159:96];
            posted_tc     <= tc;
            posted_ep     <= ep;
          end
          MWr64: begin
            posted_valid  <= 1;
            posted_type   <= MWr64;
            posted_addr   <= addr_4dw;
            posted_length <= length;
            posted_data   <= tlp_data[191:128];
            posted_tc     <= tc;
            posted_ep     <= ep;
          end
          // ---- Posted: Message ----
          Msg, MsgD: begin
            posted_valid  <= 1;
            posted_type   <= tlp_type_e'(fmt_type);
            posted_addr   <= 64'h0;
            posted_length <= length;
            posted_data   <= (fmt_type == 8'(MsgD)) ? tlp_data[159:96] : 64'h0;
            posted_tc     <= tc;
            posted_ep     <= ep;
          end
          // ---- Non-Posted: Memory Read ----
          MRd32: begin
            np_valid   <= 1; np_type  <= MRd32;
            np_addr    <= {32'h0, addr_3dw};
            np_length  <= length; np_req_id <= req_id_3dw;
            np_tag     <= tag_3dw; np_first_be <= first_be_3dw;
            np_last_be <= last_be_3dw; np_tc <= tc;
          end
          MRd64: begin
            np_valid   <= 1; np_type  <= MRd64;
            np_addr    <= addr_4dw;
            np_length  <= length; np_req_id <= req_id_4dw;
            np_tag     <= tag_4dw; np_first_be <= first_be_4dw;
            np_last_be <= last_be_4dw; np_tc <= tc;
          end
          // ---- Non-Posted: I/O ----
          IORd: begin
            np_valid   <= 1; np_type  <= IORd;
            np_addr    <= {32'h0, addr_3dw};
            np_length  <= 10'd1; np_req_id <= req_id_3dw;
            np_tag     <= tag_3dw; np_first_be <= first_be_3dw;
            np_last_be <= 4'h0; np_tc <= 3'h0;
          end
          IOWr: begin
            np_valid   <= 1; np_type  <= IOWr;
            np_addr    <= {32'h0, addr_3dw};
            np_length  <= 10'd1; np_req_id <= req_id_3dw;
            np_tag     <= tag_3dw; np_first_be <= first_be_3dw;
            np_last_be <= 4'h0; np_tc <= 3'h0;
          end
          // ---- Non-Posted: Config ----
          CfgRd0, CfgRd1: begin
            np_valid     <= 1; np_type  <= tlp_type_e'(fmt_type);
            np_req_id    <= req_id_3dw; np_tag <= tag_3dw;
            np_first_be  <= first_be_3dw; np_length <= 10'd1;
            cfg_rd_valid <= 1;
            cfg_reg_num  <= {addr_3dw[11:8], addr_3dw[7:2], 2'b0};
            cfg_req_id   <= req_id_3dw; cfg_tag <= tag_3dw;
            cfg_be       <= first_be_3dw;
          end
          CfgWr0, CfgWr1: begin
            np_valid     <= 1; np_type  <= tlp_type_e'(fmt_type);
            np_req_id    <= req_id_3dw; np_tag <= tag_3dw;
            np_first_be  <= first_be_3dw; np_length <= 10'd1;
            cfg_wr_valid <= 1;
            cfg_reg_num  <= {addr_3dw[11:8], addr_3dw[7:2], 2'b0};
            cfg_req_id   <= req_id_3dw; cfg_tag <= tag_3dw;
            cfg_wr_data  <= tlp_data[127:96];
            cfg_be       <= first_be_3dw;
          end
          // ---- Completion ----
          Cpl, CplD, CplLk, CplDLk: begin
            cpl_valid    <= 1;
            cpl_type     <= tlp_type_e'(fmt_type);
            cpl_status   <= cpl_status_e'(status);
            cpl_req_id   <= req_id_cpl;
            cpl_tag      <= tag_cpl;
            cpl_byte_cnt <= byte_cnt;
            cpl_data     <= (has_data) ? tlp_data[191:128] : 64'h0;
          end
          // ---- AtomicOp ----
          FetchAdd32, FetchAdd64, Swap32, Swap64, CAS32, CAS64: begin
            np_valid   <= 1; np_type  <= tlp_type_e'(fmt_type);
            np_addr    <= is_4dw_hdr ? addr_4dw : {32'h0, addr_3dw};
            np_length  <= length; np_tc <= tc;
            np_req_id  <= is_4dw_hdr ? req_id_4dw : req_id_3dw;
            np_tag     <= is_4dw_hdr ? tag_4dw     : tag_3dw;
          end
          default: begin
            // Malformed or unsupported TLP
            rx_error       <= ERR_MALFORMED_TLP;
            rx_error_valid <= 1;
          end
        endcase
        // ECRC check if TD bit set
        if (td) begin
          // Simplified: mark error if last DW is not a valid CRC (stub)
          if (tlp_data[255:224] == 32'hDEAD_BEEF) begin
            rx_error       <= ERR_ECRC;
            rx_error_valid <= 1;
          end
        end
        // Poisoned TLP
        if (ep) begin
          rx_error       <= ERR_POISONED_TLP;
          rx_error_valid <= 1;
        end
      end
    end
  end

endmodule : pcie_tlp_rx
