// SPI Mode 0 slave: CPOL=0, CPHA=0
// Frame: CS_N low -> send addr byte (bit7=R/W, bits[6:0]=addr), then data byte(s)
module spi_slave #(
  parameter REG_DEPTH = 8
)(
  input  logic sclk,
  input  logic cs_n,
  input  logic mosi,
  output logic miso
);

  logic [7:0] regs [0:REG_DEPTH-1];

  logic [7:0] shift_in;
  logic [7:0] shift_out;
  logic [2:0] bit_cnt;
  logic [7:0] byte_cnt;
  logic       rw_bit;
  logic [6:0] reg_addr;
  logic       addr_done;

  // Shift in on rising SCLK (CPHA=0)
  always_ff @(posedge sclk or posedge cs_n) begin
    if (cs_n) begin
      bit_cnt   <= 3'd7;
      byte_cnt  <= '0;
      addr_done <= 1'b0;
      shift_in  <= '0;
    end else begin
      shift_in <= {shift_in[6:0], mosi};
      if (bit_cnt == 3'd0) begin
        bit_cnt <= 3'd7;
        if (!addr_done) begin
          rw_bit    <= shift_in[6]; // MSB of completed byte
          reg_addr  <= shift_in[5:0];
          addr_done <= 1'b1;
          // Pre-load MISO shift reg for read
          shift_out <= rw_bit ? regs[shift_in[5:0] & (REG_DEPTH-1)] : 8'hFF;
        end else begin
          if (!rw_bit) begin
            // Write: store received data
            regs[reg_addr & (REG_DEPTH-1)] <= shift_in;
          end
          byte_cnt  <= byte_cnt + 1;
          shift_out <= regs[(reg_addr + byte_cnt + 1) & (REG_DEPTH-1)];
        end
      end else begin
        bit_cnt   <= bit_cnt - 1;
        shift_out <= {shift_out[6:0], 1'b0};
      end
    end
  end

  // Shift out on falling SCLK (CPHA=0)
  always_ff @(negedge sclk or posedge cs_n) begin
    if (cs_n)
      miso <= 1'b1;
    else
      miso <= shift_out[7];
  end

endmodule
