module ahb_slave #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32,
  parameter MEM_DEPTH  = 16
)(
  input  logic                  hclk,
  input  logic                  hresetn,
  input  logic [ADDR_WIDTH-1:0] haddr,
  input  logic [1:0]            htrans,   // 0=IDLE,1=BUSY,2=NONSEQ,3=SEQ
  input  logic                  hwrite,
  input  logic [2:0]            hsize,
  input  logic [2:0]            hburst,
  input  logic [DATA_WIDTH-1:0] hwdata,
  output logic [DATA_WIDTH-1:0] hrdata,
  output logic                  hready,
  output logic                  hresp,
  input  logic                  hsel
);

  localparam HTRANS_IDLE   = 2'b00;
  localparam HTRANS_BUSY   = 2'b01;
  localparam HTRANS_NONSEQ = 2'b10;
  localparam HTRANS_SEQ    = 2'b11;

  logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

  // Sample address phase signals
  logic                  wr_en_d1;
  logic [ADDR_WIDTH-1:0] haddr_d1;
  logic                  active;

  assign active = hsel && (htrans == HTRANS_NONSEQ || htrans == HTRANS_SEQ);

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      wr_en_d1 <= 1'b0;
      haddr_d1 <= '0;
      hready   <= 1'b1;
      hresp    <= 1'b0;
      hrdata   <= '0;
    end else begin
      hready <= 1'b1;
      hresp  <= 1'b0;

      // Address phase sample
      if (active) begin
        wr_en_d1 <= hwrite;
        haddr_d1 <= haddr;
      end else if (!active && hready) begin
        wr_en_d1 <= 1'b0;
      end

      // Data phase: write
      if (wr_en_d1 && hready) begin
        automatic logic [$clog2(MEM_DEPTH)-1:0] idx;
        idx = (haddr_d1 >> 2) & (MEM_DEPTH-1);
        mem[idx] <= hwdata;
      end

      // Data phase: read
      if (active && !hwrite) begin
        hrdata <= mem[(haddr >> 2) & (MEM_DEPTH-1)];
      end
    end
  end

endmodule
