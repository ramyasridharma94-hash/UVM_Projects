// SPI-to-I2C bridge
// SPI frame (16 bits, MSB first):
//   [15]    = R/W (1=read, 0=write)
//   [14:8]  = I2C 7-bit slave address
//   [7:0]   = data byte (write) or ignored (read)
// On CS_N rising edge: initiate I2C transaction
module spi_to_i2c_bridge #(
  parameter CLK_DIV = 10   // SCL = SCLK / CLK_DIV
)(
  input  logic sclk,
  input  logic cs_n,
  input  logic mosi,
  output logic miso,
  output logic scl,
  inout  wire  sda
);

  // SPI receive
  logic [15:0] spi_shift;
  logic [4:0]  spi_cnt;
  logic        spi_done;
  logic        spi_rw;
  logic [6:0]  i2c_addr;
  logic [7:0]  i2c_wdata;

  always_ff @(posedge sclk or posedge cs_n) begin
    if (cs_n) begin
      spi_cnt  <= '0;
      spi_done <= 1'b0;
    end else begin
      spi_shift <= {spi_shift[14:0], mosi};
      if (spi_cnt == 5'd15) begin
        spi_done  <= 1'b1;
        spi_rw    <= spi_shift[14]; // shifted in, MSB first
        i2c_addr  <= spi_shift[13:7];
        i2c_wdata <= spi_shift[6:0];
        spi_cnt   <= '0;
      end else spi_cnt <= spi_cnt + 1;
    end
  end

  // I2C master state machine (runs on SCLK domain)
  typedef enum logic [3:0] {
    I2C_IDLE, START_H, START_L, ADDR_SEND, ACK_ADDR,
    DATA_SEND, ACK_DATA, STOP_L, STOP_H, READ_DATA, READ_ACK, DONE
  } i2c_state_e;
  i2c_state_e i2c_state;

  logic       sda_out;
  logic       sda_oe;
  logic [3:0] bit_idx;
  logic [7:0] tx_byte;
  logic [7:0] rx_byte;
  logic       addr_done;
  logic [$clog2(10)-1:0] clk_div_cnt;
  logic       scl_r;
  logic       i2c_start;

  assign sda = sda_oe ? sda_out : 1'bz;
  assign scl = scl_r;
  assign miso = rx_byte[7]; // return MSB of received byte

  always_ff @(posedge sclk or posedge cs_n) begin
    if (cs_n) begin
      i2c_state   <= I2C_IDLE;
      scl_r       <= 1'b1;
      sda_oe      <= 1'b0;
      sda_out     <= 1'b1;
      clk_div_cnt <= '0;
      bit_idx     <= 4'd7;
      addr_done   <= 1'b0;
      i2c_start   <= 1'b0;
    end else begin
      if (spi_done && !i2c_start) begin
        i2c_start <= 1'b1;
        i2c_state <= START_H;
      end

      clk_div_cnt <= clk_div_cnt + 1;
      if (clk_div_cnt == CLK_DIV-1) begin
        clk_div_cnt <= '0;
        scl_r <= ~scl_r;

        case (i2c_state)
          START_H: begin
            sda_oe  <= 1'b1;
            sda_out <= 1'b0; // SDA low while SCL high = START
            i2c_state <= START_L;
          end
          START_L: begin
            scl_r   <= 1'b0;
            tx_byte <= {i2c_addr, spi_rw};
            bit_idx <= 4'd7;
            i2c_state <= ADDR_SEND;
          end
          ADDR_SEND: begin
            scl_r   <= ~scl_r;
            sda_out <= tx_byte[bit_idx];
            if (scl_r && bit_idx == 0) begin
              i2c_state <= ACK_ADDR;
              sda_oe    <= 1'b0;
            end else if (!scl_r) begin
              if (bit_idx > 0) bit_idx <= bit_idx - 1;
            end
          end
          ACK_ADDR: begin
            if (!scl_r) begin
              addr_done <= 1'b1;
              bit_idx   <= 4'd7;
              tx_byte   <= i2c_wdata;
              i2c_state <= spi_rw ? READ_DATA : DATA_SEND;
            end
          end
          DATA_SEND: begin
            sda_oe  <= 1'b1;
            sda_out <= tx_byte[bit_idx];
            scl_r   <= ~scl_r;
            if (scl_r && bit_idx == 0) begin
              i2c_state <= ACK_DATA;
              sda_oe    <= 1'b0;
            end else if (!scl_r && bit_idx > 0) begin
              bit_idx <= bit_idx - 1;
            end
          end
          ACK_DATA: begin
            if (!scl_r) begin
              i2c_state <= STOP_L;
            end
          end
          READ_DATA: begin
            sda_oe <= 1'b0;
            scl_r  <= ~scl_r;
            if (scl_r) begin
              rx_byte <= {rx_byte[6:0], sda};
              if (bit_idx == 0) begin
                i2c_state <= READ_ACK;
                bit_idx   <= 4'd7;
              end else bit_idx <= bit_idx - 1;
            end
          end
          READ_ACK: begin
            sda_oe  <= 1'b1;
            sda_out <= 1'b1; // NACK to end read
            if (!scl_r) i2c_state <= STOP_L;
          end
          STOP_L: begin
            sda_oe  <= 1'b1;
            sda_out <= 1'b0;
            scl_r   <= 1'b1;
            i2c_state <= STOP_H;
          end
          STOP_H: begin
            sda_out   <= 1'b1; // STOP condition
            i2c_state <= DONE;
            i2c_start <= 1'b0;
          end
          DONE: begin
            scl_r     <= 1'b1;
            sda_oe    <= 1'b0;
            i2c_state <= I2C_IDLE;
          end
          default: i2c_state <= I2C_IDLE;
        endcase
      end
    end
  end

endmodule
