// I2C slave with 7-bit addressing, fixed address 0x50
// Supports write and repeated-start read
module i2c_slave #(
  parameter SLAVE_ADDR = 7'h50,
  parameter REG_DEPTH  = 8
)(
  input  logic       scl,
  inout  wire        sda
);

  logic [7:0] regs [0:REG_DEPTH-1];

  typedef enum logic [3:0] {
    IDLE, START_DET, ADDR_BYTE, ADDR_ACK,
    REG_BYTE, REG_ACK, DATA_WRITE, DATA_WRITE_ACK,
    DATA_READ, DATA_READ_ACK, STOP_DET
  } state_e;

  state_e state;

  logic       sda_out;
  logic       sda_oe;
  logic [7:0] shift_reg;
  logic [2:0] bit_cnt;
  logic [6:0] rcv_addr;
  logic       rw_bit;
  logic [7:0] reg_ptr;
  logic       prev_sda, prev_scl;
  logic       start_det, stop_det;

  assign sda = sda_oe ? sda_out : 1'bz;

  // START/STOP detection: SDA changes while SCL high
  always_ff @(posedge scl or negedge scl) begin
    prev_sda <= sda;
    prev_scl <= scl;
  end

  assign start_det = prev_scl && scl && prev_sda && !sda;
  assign stop_det  = prev_scl && scl && !prev_sda && sda;

  always_ff @(negedge scl or posedge start_det or posedge stop_det) begin
    if (stop_det || (!start_det && state == IDLE)) begin
      state   <= IDLE;
      sda_oe  <= 1'b0;
      sda_out <= 1'b1;
      bit_cnt <= 3'd7;
    end else if (start_det) begin
      state   <= ADDR_BYTE;
      bit_cnt <= 3'd7;
      sda_oe  <= 1'b0;
    end else begin
      case (state)
        ADDR_BYTE: begin
          shift_reg <= {shift_reg[6:0], sda};
          if (bit_cnt == 0) begin
            rcv_addr <= shift_reg[7:1];
            rw_bit   <= shift_reg[0];
            bit_cnt  <= 3'd7;
            state    <= ADDR_ACK;
          end else bit_cnt <= bit_cnt - 1;
        end
        ADDR_ACK: begin
          if (rcv_addr == SLAVE_ADDR) begin
            sda_oe  <= 1'b1;
            sda_out <= 1'b0; // ACK
            state   <= rw_bit ? DATA_READ : REG_BYTE;
          end else begin
            sda_oe  <= 1'b1;
            sda_out <= 1'b1; // NACK
            state   <= IDLE;
          end
        end
        REG_BYTE: begin
          sda_oe    <= 1'b0;
          shift_reg <= {shift_reg[6:0], sda};
          if (bit_cnt == 0) begin
            reg_ptr <= shift_reg[6:0];
            bit_cnt <= 3'd7;
            state   <= REG_ACK;
          end else bit_cnt <= bit_cnt - 1;
        end
        REG_ACK: begin
          sda_oe  <= 1'b1;
          sda_out <= 1'b0;
          state   <= DATA_WRITE;
        end
        DATA_WRITE: begin
          sda_oe    <= 1'b0;
          shift_reg <= {shift_reg[6:0], sda};
          if (bit_cnt == 0) begin
            regs[reg_ptr & (REG_DEPTH-1)] <= {shift_reg[6:0], sda};
            reg_ptr <= reg_ptr + 1;
            bit_cnt <= 3'd7;
            state   <= DATA_WRITE_ACK;
          end else bit_cnt <= bit_cnt - 1;
        end
        DATA_WRITE_ACK: begin
          sda_oe  <= 1'b1;
          sda_out <= 1'b0;
          state   <= DATA_WRITE;
        end
        DATA_READ: begin
          sda_oe  <= 1'b1;
          sda_out <= regs[reg_ptr & (REG_DEPTH-1)][bit_cnt];
          if (bit_cnt == 0) begin
            reg_ptr <= reg_ptr + 1;
            bit_cnt <= 3'd7;
            state   <= DATA_READ_ACK;
          end else bit_cnt <= bit_cnt - 1;
        end
        DATA_READ_ACK: begin
          sda_oe <= 1'b0; // release for master ACK/NACK
          state  <= sda ? IDLE : DATA_READ;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule
