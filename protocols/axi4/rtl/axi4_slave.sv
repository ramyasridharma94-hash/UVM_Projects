module axi4_slave #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32,
  parameter ID_WIDTH   = 4,
  parameter MEM_DEPTH  = 16
)(
  input  logic                    aclk,
  input  logic                    aresetn,
  // Write Address Channel
  input  logic [ID_WIDTH-1:0]     awid,
  input  logic [ADDR_WIDTH-1:0]   awaddr,
  input  logic [7:0]              awlen,
  input  logic [2:0]              awsize,
  input  logic [1:0]              awburst,
  input  logic                    awvalid,
  output logic                    awready,
  // Write Data Channel
  input  logic [DATA_WIDTH-1:0]   wdata,
  input  logic [DATA_WIDTH/8-1:0] wstrb,
  input  logic                    wlast,
  input  logic                    wvalid,
  output logic                    wready,
  // Write Response Channel
  output logic [ID_WIDTH-1:0]     bid,
  output logic [1:0]              bresp,
  output logic                    bvalid,
  input  logic                    bready,
  // Read Address Channel
  input  logic [ID_WIDTH-1:0]     arid,
  input  logic [ADDR_WIDTH-1:0]   araddr,
  input  logic [7:0]              arlen,
  input  logic [2:0]              arsize,
  input  logic [1:0]              arburst,
  input  logic                    arvalid,
  output logic                    arready,
  // Read Data Channel
  output logic [ID_WIDTH-1:0]     rid,
  output logic [DATA_WIDTH-1:0]   rdata,
  output logic [1:0]              rresp,
  output logic                    rlast,
  output logic                    rvalid,
  input  logic                    rready
);

  logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

  // ---------- Write Path ----------
  typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} w_state_e;
  w_state_e w_state;

  logic [ID_WIDTH-1:0]   wr_id;
  logic [ADDR_WIDTH-1:0] wr_curr_addr;
  logic [7:0]            wr_len;
  logic [7:0]            wr_cnt;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      w_state  <= W_IDLE;
      awready  <= 1'b1;
      wready   <= 1'b0;
      bvalid   <= 1'b0;
      bid      <= '0;
      bresp    <= 2'b00;
      wr_cnt   <= '0;
    end else begin
      case (w_state)
        W_IDLE: begin
          if (awvalid && awready) begin
            wr_id        <= awid;
            wr_curr_addr <= awaddr;
            wr_len       <= awlen;
            wr_cnt       <= '0;
            awready      <= 1'b0;
            wready       <= 1'b1;
            w_state      <= W_DATA;
          end
        end
        W_DATA: begin
          if (wvalid && wready) begin
            automatic logic [$clog2(MEM_DEPTH)-1:0] idx;
            idx = (wr_curr_addr >> 2) & (MEM_DEPTH-1);
            for (int i = 0; i < DATA_WIDTH/8; i++)
              if (wstrb[i]) mem[idx][i*8 +: 8] <= wdata[i*8 +: 8];
            wr_curr_addr <= wr_curr_addr + (1 << awsize);
            wr_cnt       <= wr_cnt + 1;
            if (wlast) begin
              wready  <= 1'b0;
              bvalid  <= 1'b1;
              bid     <= wr_id;
              bresp   <= 2'b00;
              w_state <= W_RESP;
            end
          end
        end
        W_RESP: begin
          if (bvalid && bready) begin
            bvalid  <= 1'b0;
            awready <= 1'b1;
            w_state <= W_IDLE;
          end
        end
      endcase
    end
  end

  // ---------- Read Path ----------
  typedef enum logic [1:0] {R_IDLE, R_DATA} r_state_e;
  r_state_e r_state;

  logic [ID_WIDTH-1:0]   rd_id;
  logic [ADDR_WIDTH-1:0] rd_curr_addr;
  logic [7:0]            rd_len;
  logic [7:0]            rd_cnt;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      r_state <= R_IDLE;
      arready <= 1'b1;
      rvalid  <= 1'b0;
      rlast   <= 1'b0;
      rid     <= '0;
      rdata   <= '0;
      rresp   <= 2'b00;
      rd_cnt  <= '0;
    end else begin
      case (r_state)
        R_IDLE: begin
          if (arvalid && arready) begin
            rd_id        <= arid;
            rd_curr_addr <= araddr;
            rd_len       <= arlen;
            rd_cnt       <= '0;
            arready      <= 1'b0;
            rvalid       <= 1'b1;
            rid          <= arid;
            rdata        <= mem[(araddr >> 2) & (MEM_DEPTH-1)];
            rresp        <= 2'b00;
            rlast        <= (arlen == 8'h00);
            r_state      <= R_DATA;
          end
        end
        R_DATA: begin
          if (rvalid && rready) begin
            if (rlast) begin
              rvalid  <= 1'b0;
              arready <= 1'b1;
              r_state <= R_IDLE;
            end else begin
              rd_cnt       <= rd_cnt + 1;
              rd_curr_addr <= rd_curr_addr + 4;
              rdata        <= mem[((rd_curr_addr + 4) >> 2) & (MEM_DEPTH-1)];
              rlast        <= (rd_cnt + 1 == rd_len);
              rid          <= rd_id;
            end
          end
        end
      endcase
    end
  end

endmodule
