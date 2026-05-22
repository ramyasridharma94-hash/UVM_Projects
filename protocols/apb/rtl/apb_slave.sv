module apb_slave #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32,
  parameter MEM_DEPTH  = 8
)(
  input  logic                  pclk,
  input  logic                  presetn,
  input  logic [ADDR_WIDTH-1:0] paddr,
  input  logic                  psel,
  input  logic                  penable,
  input  logic                  pwrite,
  input  logic [DATA_WIDTH-1:0] pwdata,
  output logic [DATA_WIDTH-1:0] prdata,
  output logic                  pready,
  output logic                  pslverr
);

  logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

  // 1-cycle extra wait state to exercise pready
  logic wait_done;

  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      prdata    <= '0;
      pready    <= 1'b0;
      pslverr   <= 1'b0;
      wait_done <= 1'b0;
    end else begin
      pslverr <= 1'b0;
      pready  <= 1'b0;

      if (psel && !penable) begin
        // SETUP phase — assert wait
        wait_done <= 1'b0;
        pready    <= 1'b0;
      end else if (psel && penable) begin
        if (!wait_done) begin
          // Insert one wait state
          wait_done <= 1'b1;
          pready    <= 1'b0;
        end else begin
          wait_done <= 1'b0;
          pready    <= 1'b1;

          if ((paddr >> 2) >= MEM_DEPTH) begin
            pslverr <= 1'b1;
          end else if (pwrite) begin
            mem[(paddr >> 2) & (MEM_DEPTH-1)] <= pwdata;
          end else begin
            prdata <= mem[(paddr >> 2) & (MEM_DEPTH-1)];
          end
        end
      end
    end
  end

endmodule
