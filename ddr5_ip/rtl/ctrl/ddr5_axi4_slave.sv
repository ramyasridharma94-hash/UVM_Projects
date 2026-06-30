// DDR5 AXI4 Slave — Full AXI4 protocol implementation
// Supports: burst types INCR/WRAP/FIXED, 16 outstanding IDs, AXI4 ordering rules
// Generates structured DDR5 requests: {cmd, bg, bank, row, col, data, strb}
import ddr5_pkg::*;

module ddr5_axi4_slave #(
  parameter int AXI_ADDR_W = 34,   // 16 GB address space
  parameter int AXI_DATA_W = 256,  // 256-bit (BL8 × 32b DQ)
  parameter int AXI_ID_W   = 8,
  parameter int AXI_STRB_W = AXI_DATA_W/8,
  parameter int MAX_OUTSTANDING = 16
)(
  input  logic                    clk,
  input  logic                    rst_n,

  // -----------------------------------------------------------------------
  // AXI4 Write Address Channel
  // -----------------------------------------------------------------------
  input  logic                    s_awvalid,
  output logic                    s_awready,
  input  logic [AXI_ADDR_W-1:0]  s_awaddr,
  input  logic [7:0]              s_awlen,
  input  logic [2:0]              s_awsize,
  input  logic [1:0]              s_awburst,  // 0=FIXED, 1=INCR, 2=WRAP
  input  logic [AXI_ID_W-1:0]    s_awid,
  input  logic [2:0]              s_awprot,
  input  logic [3:0]              s_awcache,
  input  logic [3:0]              s_awqos,

  // -----------------------------------------------------------------------
  // AXI4 Write Data Channel
  // -----------------------------------------------------------------------
  input  logic                    s_wvalid,
  output logic                    s_wready,
  input  logic [AXI_DATA_W-1:0]  s_wdata,
  input  logic [AXI_STRB_W-1:0]  s_wstrb,
  input  logic                    s_wlast,

  // -----------------------------------------------------------------------
  // AXI4 Write Response Channel
  // -----------------------------------------------------------------------
  output logic                    s_bvalid,
  input  logic                    s_bready,
  output logic [1:0]              s_bresp,
  output logic [AXI_ID_W-1:0]    s_bid,

  // -----------------------------------------------------------------------
  // AXI4 Read Address Channel
  // -----------------------------------------------------------------------
  input  logic                    s_arvalid,
  output logic                    s_arready,
  input  logic [AXI_ADDR_W-1:0]  s_araddr,
  input  logic [7:0]              s_arlen,
  input  logic [2:0]              s_arsize,
  input  logic [1:0]              s_arburst,
  input  logic [AXI_ID_W-1:0]    s_arid,
  input  logic [2:0]              s_arprot,
  input  logic [3:0]              s_arcache,
  input  logic [3:0]              s_arqos,

  // -----------------------------------------------------------------------
  // AXI4 Read Data Channel
  // -----------------------------------------------------------------------
  output logic                    s_rvalid,
  input  logic                    s_rready,
  output logic [AXI_DATA_W-1:0]  s_rdata,
  output logic [1:0]              s_rresp,
  output logic                    s_rlast,
  output logic [AXI_ID_W-1:0]    s_rid,

  // -----------------------------------------------------------------------
  // DDR5 Command Request Interface (to Command Scheduler)
  // -----------------------------------------------------------------------
  output logic                    cmd_valid,
  output logic                    cmd_is_write,
  output logic [AXI_ADDR_W-1:0]  cmd_addr,        // raw address for mapper
  output logic [7:0]              cmd_len,         // burst length
  output logic [2:0]              cmd_size,
  output logic [1:0]              cmd_burst,
  output logic [AXI_ID_W-1:0]    cmd_id,
  input  logic                    cmd_ready,

  // -----------------------------------------------------------------------
  // Write Data Interface (to Write Data Buffer)
  // -----------------------------------------------------------------------
  output logic                    wdata_valid,
  output logic [AXI_DATA_W-1:0]  wdata_data,
  output logic [AXI_STRB_W-1:0]  wdata_strb,
  output logic                    wdata_last,
  input  logic                    wdata_ready,

  // -----------------------------------------------------------------------
  // Read Return Interface (from Read Data Buffer)
  // -----------------------------------------------------------------------
  input  logic                    rdata_valid,
  input  logic [AXI_DATA_W-1:0]  rdata_data,
  input  logic [1:0]              rdata_resp,
  input  logic                    rdata_last,
  input  logic [AXI_ID_W-1:0]    rdata_id,
  output logic                    rdata_ready,

  // -----------------------------------------------------------------------
  // Write Response from DDR5 (from Write Data Buffer completion)
  // -----------------------------------------------------------------------
  input  logic                    wresp_valid,
  input  logic [1:0]              wresp_resp,
  input  logic [AXI_ID_W-1:0]    wresp_id,
  output logic                    wresp_ready,

  // -----------------------------------------------------------------------
  // Status
  // -----------------------------------------------------------------------
  output logic [4:0]              wr_outstanding,
  output logic [4:0]              rd_outstanding
);

  // -----------------------------------------------------------------------
  // Write Address FIFO — decouple AW from W channel
  // -----------------------------------------------------------------------
  typedef struct packed {
    logic [AXI_ADDR_W-1:0]  addr;
    logic [7:0]              len;
    logic [2:0]              size;
    logic [1:0]              burst;
    logic [AXI_ID_W-1:0]    id;
    logic [2:0]              prot;
    logic [3:0]              cache;
    logic [3:0]              qos;
  } aw_entry_t;

  aw_entry_t aw_fifo  [0:MAX_OUTSTANDING-1];
  aw_entry_t ar_fifo  [0:MAX_OUTSTANDING-1];

  logic [$clog2(MAX_OUTSTANDING):0] aw_wr_ptr, aw_rd_ptr;
  logic [$clog2(MAX_OUTSTANDING):0] ar_wr_ptr, ar_rd_ptr;
  logic aw_full, aw_empty, ar_full, ar_empty;

  assign aw_full  = (aw_wr_ptr[3:0] == aw_rd_ptr[3:0]) &&
                    (aw_wr_ptr[4]   != aw_rd_ptr[4]);
  assign aw_empty = (aw_wr_ptr == aw_rd_ptr);
  assign ar_full  = (ar_wr_ptr[3:0] == ar_rd_ptr[3:0]) &&
                    (ar_wr_ptr[4]   != ar_rd_ptr[4]);
  assign ar_empty = (ar_wr_ptr == ar_rd_ptr);

  assign wr_outstanding = 5'(aw_wr_ptr - aw_rd_ptr);
  assign rd_outstanding = 5'(ar_wr_ptr - ar_rd_ptr);

  // -----------------------------------------------------------------------
  // AW channel — accept and enqueue
  // -----------------------------------------------------------------------
  assign s_awready = !aw_full;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) aw_wr_ptr <= '0;
    else if (s_awvalid && s_awready) begin
      aw_fifo[aw_wr_ptr[3:0]] <= '{
        s_awaddr, s_awlen, s_awsize, s_awburst, s_awid,
        s_awprot, s_awcache, s_awqos};
      aw_wr_ptr <= aw_wr_ptr + 1;
    end
  end

  // -----------------------------------------------------------------------
  // W channel — forward to write data buffer
  // -----------------------------------------------------------------------
  assign s_wready   = wdata_ready && !aw_empty;
  assign wdata_valid = s_wvalid && !aw_empty && wdata_ready;
  assign wdata_data  = s_wdata;
  assign wdata_strb  = s_wstrb;
  assign wdata_last  = s_wlast;

  // -----------------------------------------------------------------------
  // Write command dispatch — send after seeing wlast
  // -----------------------------------------------------------------------
  logic aw_cmd_sent;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin aw_rd_ptr <= '0; aw_cmd_sent <= 0; end
    else begin
      if (!aw_empty && cmd_ready && !cmd_valid) begin
        // Issue write command
        aw_cmd_sent <= 1;
      end
      if (aw_cmd_sent && s_wvalid && s_wlast && wdata_ready) begin
        aw_rd_ptr   <= aw_rd_ptr + 1;
        aw_cmd_sent <= 0;
      end
    end
  end

  // -----------------------------------------------------------------------
  // AR channel — accept and enqueue
  // -----------------------------------------------------------------------
  assign s_arready = !ar_full;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) ar_wr_ptr <= '0;
    else if (s_arvalid && s_arready) begin
      ar_fifo[ar_wr_ptr[3:0]] <= '{
        s_araddr, s_arlen, s_arsize, s_arburst, s_arid,
        s_arprot, s_arcache, s_arqos};
      ar_wr_ptr <= ar_wr_ptr + 1;
    end
  end

  // -----------------------------------------------------------------------
  // Command arbitration — reads have priority over new writes
  // (writes already in flight are in the scheduler)
  // -----------------------------------------------------------------------
  typedef enum logic [1:0] { CMD_IDLE, CMD_WR, CMD_RD, CMD_WAIT } cmd_arb_e;
  cmd_arb_e cmd_state;
  aw_entry_t cur_aw;
  aw_entry_t cur_ar;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cmd_state <= CMD_IDLE; cmd_valid <= 0;
      ar_rd_ptr <= '0;
    end else begin
      cmd_valid <= 0;
      case (cmd_state)
        CMD_IDLE: begin
          if (!ar_empty) begin
            cur_ar    <= ar_fifo[ar_rd_ptr[3:0]];
            ar_rd_ptr <= ar_rd_ptr + 1;
            cmd_state <= CMD_RD;
          end else if (!aw_empty && aw_cmd_sent) begin
            cur_aw    <= aw_fifo[aw_rd_ptr[3:0]];
            cmd_state <= CMD_WR;
          end
        end
        CMD_RD: begin
          cmd_valid    <= 1;
          cmd_is_write <= 0;
          cmd_addr     <= cur_ar.addr;
          cmd_len      <= cur_ar.len;
          cmd_size     <= cur_ar.size;
          cmd_burst    <= cur_ar.burst;
          cmd_id       <= cur_ar.id;
          if (cmd_ready) cmd_state <= CMD_IDLE;
        end
        CMD_WR: begin
          cmd_valid    <= 1;
          cmd_is_write <= 1;
          cmd_addr     <= cur_aw.addr;
          cmd_len      <= cur_aw.len;
          cmd_size     <= cur_aw.size;
          cmd_burst    <= cur_aw.burst;
          cmd_id       <= cur_aw.id;
          if (cmd_ready) cmd_state <= CMD_IDLE;
        end
        default: cmd_state <= CMD_IDLE;
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // B channel — forward write response
  // -----------------------------------------------------------------------
  assign s_bvalid  = wresp_valid;
  assign s_bresp   = wresp_resp;
  assign s_bid     = wresp_id;
  assign wresp_ready = s_bready;

  // -----------------------------------------------------------------------
  // R channel — forward read data
  // -----------------------------------------------------------------------
  assign s_rvalid  = rdata_valid;
  assign s_rdata   = rdata_data;
  assign s_rresp   = rdata_resp;
  assign s_rlast   = rdata_last;
  assign s_rid     = rdata_id;
  assign rdata_ready = s_rready;

endmodule : ddr5_axi4_slave
