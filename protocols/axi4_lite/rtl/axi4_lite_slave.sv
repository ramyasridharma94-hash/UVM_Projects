module axi4_lite_slave #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32,
  parameter MEM_DEPTH  = 8
)(
  input  logic                    aclk,
  input  logic                    aresetn,
  // Write Address Channel
  input  logic [ADDR_WIDTH-1:0]   awaddr,
  input  logic                    awvalid,
  output logic                    awready,
  // Write Data Channel
  input  logic [DATA_WIDTH-1:0]   wdata,
  input  logic [DATA_WIDTH/8-1:0] wstrb,
  input  logic                    wvalid,
  output logic                    wready,
  // Write Response Channel
  output logic [1:0]              bresp,
  output logic                    bvalid,
  input  logic                    bready,
  // Read Address Channel
  input  logic [ADDR_WIDTH-1:0]   araddr,
  input  logic                    arvalid,
  output logic                    arready,
  // Read Data Channel
  output logic [DATA_WIDTH-1:0]   rdata,
  output logic [1:0]              rresp,
  output logic                    rvalid,
  input  logic                    rready
);

  logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

  // ---------- Write Path ----------
  typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} w_state_e;
  w_state_e w_state;

  logic [ADDR_WIDTH-1:0] wr_addr;
  logic                  addr_done, data_done;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      w_state   <= W_IDLE;
      awready   <= 1'b0;
      wready    <= 1'b0;
      bvalid    <= 1'b0;
      bresp     <= 2'b00;
      addr_done <= 1'b0;
      data_done <= 1'b0;
      wr_addr   <= '0;
    end else begin
      case (w_state)
        W_IDLE: begin
          awready <= 1'b1;
          wready  <= 1'b1;
          if (awvalid) begin
            wr_addr   <= awaddr;
            awready   <= 1'b0;
            addr_done <= 1'b1;
          end
          if (wvalid && addr_done) begin
            automatic logic [$clog2(MEM_DEPTH)-1:0] idx;
            idx = (wr_addr >> 2) & (MEM_DEPTH-1);
            for (int i = 0; i < DATA_WIDTH/8; i++)
              if (wstrb[i]) mem[idx][i*8 +: 8] <= wdata[i*8 +: 8];
            wready    <= 1'b0;
            bvalid    <= 1'b1;
            bresp     <= 2'b00;
            addr_done <= 1'b0;
            w_state   <= W_RESP;
          end
        end
        W_RESP: begin
          if (bvalid && bready) begin
            bvalid  <= 1'b0;
            w_state <= W_IDLE;
          end
        end
        default: w_state <= W_IDLE;
      endcase
    end
  end

  // ---------- Read Path ----------
  typedef enum logic [1:0] {R_IDLE, R_DATA} r_state_e;
  r_state_e r_state;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      r_state <= R_IDLE;
      arready <= 1'b1;
      rvalid  <= 1'b0;
      rdata   <= '0;
      rresp   <= 2'b00;
    end else begin
      case (r_state)
        R_IDLE: begin
          if (arvalid && arready) begin
            arready <= 1'b0;
            rvalid  <= 1'b1;
            rdata   <= mem[(araddr >> 2) & (MEM_DEPTH-1)];
            rresp   <= 2'b00;
            r_state <= R_DATA;
          end
        end
        R_DATA: begin
          if (rvalid && rready) begin
            rvalid  <= 1'b0;
            arready <= 1'b1;
            r_state <= R_IDLE;
          end
        end
      endcase
    end
  end

endmodule
