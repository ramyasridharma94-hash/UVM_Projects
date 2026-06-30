// DDR5 Write Data Buffer
// Accepts AXI4 burst write beats, assembles into DDR5 BL8/BL16 payloads,
// tracks outstanding write IDs, issues write response (B channel) on completion
import ddr5_pkg::*;

module ddr5_wr_data_buf #(
  parameter int AXI_DATA_W  = 256,
  parameter int AXI_STRB_W  = AXI_DATA_W/8,
  parameter int AXI_ID_W    = 8,
  parameter int DQ_WIDTH    = 32,
  parameter int BUF_DEPTH   = 8    // outstanding write transactions
)(
  input  logic                    clk,
  input  logic                    rst_n,

  // From AXI4 slave W channel
  input  logic                    wdata_valid,
  input  logic [AXI_DATA_W-1:0]  wdata_data,
  input  logic [AXI_STRB_W-1:0]  wdata_strb,
  input  logic                    wdata_last,
  output logic                    wdata_ready,

  // Write command (from AXI4 slave AW channel)
  input  logic                    wcmd_valid,
  input  logic [7:0]              wcmd_len,    // AXI burst length - 1
  input  logic [AXI_ID_W-1:0]    wcmd_id,
  output logic                    wcmd_ready,

  // To DDR5 DFI write path
  output logic                    dfi_wrdata_valid,
  output logic [DQ_WIDTH*8-1:0]  dfi_wrdata,
  output logic [DQ_WIDTH-1:0]    dfi_wrmask,
  output logic                    dfi_wrlast,
  input  logic                    dfi_wrdata_ready,

  // Write response to AXI4 slave B channel
  output logic                    wresp_valid,
  output logic [1:0]              wresp_resp,
  output logic [AXI_ID_W-1:0]    wresp_id,
  input  logic                    wresp_ready,

  // Status
  output logic [3:0]              buf_used
);

  // -----------------------------------------------------------------------
  // Per-entry buffer: stores one full DDR5 write burst
  // -----------------------------------------------------------------------
  typedef struct packed {
    logic [DQ_WIDTH*8-1:0] data;
    logic [DQ_WIDTH-1:0]   mask;    // DDR5 mask (inverted strb)
    logic                  valid;
    logic [7:0]            len;
    logic [AXI_ID_W-1:0]  id;
  } wbuf_entry_t;

  wbuf_entry_t wbuf [0:BUF_DEPTH-1];
  logic [$clog2(BUF_DEPTH):0] wr_ptr, rd_ptr;
  logic full, empty;

  assign full  = (wr_ptr[$clog2(BUF_DEPTH)] != rd_ptr[$clog2(BUF_DEPTH)]) &&
                 (wr_ptr[$clog2(BUF_DEPTH)-1:0] == rd_ptr[$clog2(BUF_DEPTH)-1:0]);
  assign empty = (wr_ptr == rd_ptr);
  assign buf_used = 4'(wr_ptr - rd_ptr);

  assign wcmd_ready  = !full;
  assign wdata_ready = wcmd_valid && !full;

  // -----------------------------------------------------------------------
  // Write side — accumulate beats into single BL8 payload
  // DDR5 BL8 = 8 beats × 32-bit DQ = 256-bit payload
  // AXI4 single beat = 256-bit (one full BL8 in one AXI transfer)
  // -----------------------------------------------------------------------
  logic [2:0]  beat_cnt;
  logic        filling;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0; filling <= 0; beat_cnt <= 0;
      for (int i=0; i<BUF_DEPTH; i++) wbuf[i] <= '0;
    end else begin
      if (wcmd_valid && wcmd_ready) begin
        wbuf[wr_ptr[$clog2(BUF_DEPTH)-1:0]].len   <= wcmd_len;
        wbuf[wr_ptr[$clog2(BUF_DEPTH)-1:0]].id    <= wcmd_id;
        wbuf[wr_ptr[$clog2(BUF_DEPTH)-1:0]].valid <= 0;
        filling <= 1; beat_cnt <= 0;
      end
      if (wdata_valid && wdata_ready) begin
        // Accumulate data — for BL8×32b, one AXI4 256b beat = full BL8
        wbuf[wr_ptr[$clog2(BUF_DEPTH)-1:0]].data  <= wdata_data;
        // Convert AXI strb (1=valid) to DDR5 mask (1=mask/suppress)
        wbuf[wr_ptr[$clog2(BUF_DEPTH)-1:0]].mask  <=
          {{(DQ_WIDTH-AXI_STRB_W){1'b0}}, ~wdata_strb[DQ_WIDTH-1:0]};
        if (wdata_last) begin
          wbuf[wr_ptr[$clog2(BUF_DEPTH)-1:0]].valid <= 1;
          wr_ptr  <= wr_ptr + 1;
          filling <= 0;
        end
      end
    end
  end

  // -----------------------------------------------------------------------
  // Read side — send to DFI write path
  // -----------------------------------------------------------------------
  typedef enum logic [1:0] { WSEND_IDLE, WSEND_DATA, WSEND_RESP } wsend_e;
  wsend_e wsend_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wsend_state <= WSEND_IDLE; rd_ptr <= '0;
      dfi_wrdata_valid <= 0; wresp_valid <= 0;
    end else begin
      case (wsend_state)
        WSEND_IDLE: begin
          dfi_wrdata_valid <= 0; wresp_valid <= 0;
          if (!empty && wbuf[rd_ptr[$clog2(BUF_DEPTH)-1:0]].valid) begin
            dfi_wrdata_valid <= 1;
            dfi_wrdata <= wbuf[rd_ptr[$clog2(BUF_DEPTH)-1:0]].data;
            dfi_wrmask <= wbuf[rd_ptr[$clog2(BUF_DEPTH)-1:0]].mask;
            dfi_wrlast <= 1;
            wsend_state <= WSEND_DATA;
          end
        end
        WSEND_DATA: begin
          if (dfi_wrdata_ready) begin
            dfi_wrdata_valid <= 0;
            wresp_valid      <= 1;
            wresp_resp       <= 2'b00;   // OKAY
            wresp_id         <= wbuf[rd_ptr[$clog2(BUF_DEPTH)-1:0]].id;
            rd_ptr           <= rd_ptr + 1;
            wsend_state      <= WSEND_RESP;
          end
        end
        WSEND_RESP: begin
          if (wresp_ready) begin
            wresp_valid <= 0;
            wsend_state <= WSEND_IDLE;
          end
        end
      endcase
    end
  end

  assign dfi_wrlast = dfi_wrdata_valid;

endmodule : ddr5_wr_data_buf
