// DDR5 Read Data Buffer
// Receives DDR5 BL8/BL16 read completions from PHY (dfi_rddata_valid),
// reassembles into AXI4 burst responses maintaining ID ordering
import ddr5_pkg::*;

module ddr5_rd_data_buf #(
  parameter int AXI_DATA_W = 256,
  parameter int AXI_ID_W   = 8,
  parameter int DQ_WIDTH   = 32,
  parameter int BUF_DEPTH  = 8
)(
  input  logic                    clk,
  input  logic                    rst_n,

  // Read command tracking (from scheduler, when RD command issued)
  input  logic                    rdcmd_valid,
  input  logic [7:0]              rdcmd_len,
  input  logic [AXI_ID_W-1:0]    rdcmd_id,
  output logic                    rdcmd_ready,

  // From PHY DFI read data return
  input  logic                    dfi_rddata_valid,
  input  logic [DQ_WIDTH*8-1:0]  dfi_rddata,    // BL8 = 8 × 32b = 256b

  // AXI4 R channel output
  output logic                    rdata_valid,
  output logic [AXI_DATA_W-1:0]  rdata_data,
  output logic [1:0]              rdata_resp,
  output logic                    rdata_last,
  output logic [AXI_ID_W-1:0]    rdata_id,
  input  logic                    rdata_ready,

  // Status
  output logic [3:0]              buf_used,
  output logic                    buf_full
);

  // -----------------------------------------------------------------------
  // Pending read ID queue (FIFO): stores ID in issue order
  // -----------------------------------------------------------------------
  typedef struct packed {
    logic [AXI_ID_W-1:0]  id;
    logic [7:0]            len;
    logic                  valid;
  } rdq_entry_t;

  rdq_entry_t rdq [0:BUF_DEPTH-1];
  logic [$clog2(BUF_DEPTH):0] rdq_wr_ptr, rdq_rd_ptr;
  logic rdq_full, rdq_empty;

  assign rdq_full  = (rdq_wr_ptr[$clog2(BUF_DEPTH)] != rdq_rd_ptr[$clog2(BUF_DEPTH)]) &&
                     (rdq_wr_ptr[$clog2(BUF_DEPTH)-1:0] == rdq_rd_ptr[$clog2(BUF_DEPTH)-1:0]);
  assign rdq_empty = (rdq_wr_ptr == rdq_rd_ptr);

  assign rdcmd_ready = !rdq_full;
  assign buf_full    = rdq_full;
  assign buf_used    = 4'(rdq_wr_ptr - rdq_rd_ptr);

  // Enqueue read command
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin rdq_wr_ptr <= '0; end
    else if (rdcmd_valid && rdcmd_ready) begin
      rdq[rdq_wr_ptr[$clog2(BUF_DEPTH)-1:0]].id    <= rdcmd_id;
      rdq[rdq_wr_ptr[$clog2(BUF_DEPTH)-1:0]].len   <= rdcmd_len;
      rdq[rdq_wr_ptr[$clog2(BUF_DEPTH)-1:0]].valid <= 0;
      rdq_wr_ptr <= rdq_wr_ptr + 1;
    end
  end

  // -----------------------------------------------------------------------
  // Receive DFI read data and tag with pending ID
  // -----------------------------------------------------------------------
  logic [$clog2(BUF_DEPTH):0] fill_ptr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) fill_ptr <= '0;
    else if (dfi_rddata_valid && !rdq_full) begin
      rdq[fill_ptr[$clog2(BUF_DEPTH)-1:0]].valid <= 1;
      fill_ptr <= fill_ptr + 1;
    end
  end

  // -----------------------------------------------------------------------
  // Data store: holds actual read data for each pending entry
  // -----------------------------------------------------------------------
  logic [AXI_DATA_W-1:0] data_store [0:BUF_DEPTH-1];
  logic [$clog2(BUF_DEPTH):0] data_wr, data_rd;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) data_wr <= '0;
    else if (dfi_rddata_valid) begin
      data_store[data_wr[$clog2(BUF_DEPTH)-1:0]] <= dfi_rddata[AXI_DATA_W-1:0];
      data_wr <= data_wr + 1;
    end
  end

  // -----------------------------------------------------------------------
  // AXI4 R channel output — drain in order
  // -----------------------------------------------------------------------
  logic [7:0]  beat_remaining;
  typedef enum logic [1:0] { ROUT_IDLE, ROUT_DATA } rout_e;
  rout_e rout_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rout_state <= ROUT_IDLE; rdq_rd_ptr <= '0; data_rd <= '0;
      rdata_valid <= 0; beat_remaining <= '0;
    end else begin
      case (rout_state)
        ROUT_IDLE: begin
          rdata_valid <= 0;
          if (!rdq_empty && rdq[rdq_rd_ptr[$clog2(BUF_DEPTH)-1:0]].valid) begin
            rdata_valid        <= 1;
            rdata_data         <= data_store[data_rd[$clog2(BUF_DEPTH)-1:0]];
            rdata_id           <= rdq[rdq_rd_ptr[$clog2(BUF_DEPTH)-1:0]].id;
            rdata_resp         <= 2'b00;  // OKAY
            beat_remaining     <= rdq[rdq_rd_ptr[$clog2(BUF_DEPTH)-1:0]].len;
            rdata_last         <= (rdq[rdq_rd_ptr[$clog2(BUF_DEPTH)-1:0]].len == 0);
            rout_state         <= ROUT_DATA;
          end
        end
        ROUT_DATA: begin
          if (rdata_valid && rdata_ready) begin
            if (beat_remaining == 0) begin
              rdata_valid <= 0;
              rdq_rd_ptr  <= rdq_rd_ptr + 1;
              data_rd     <= data_rd + 1;
              rout_state  <= ROUT_IDLE;
            end else begin
              beat_remaining <= beat_remaining - 1;
              data_rd        <= data_rd + 1;
              rdata_data     <= data_store[data_rd[$clog2(BUF_DEPTH)-1:0] + 1];
              rdata_last     <= (beat_remaining == 1);
            end
          end
        end
      endcase
    end
  end

endmodule : ddr5_rd_data_buf
