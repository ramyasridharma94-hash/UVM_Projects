// PCIe-to-AHB Bridge RTL
// Translates PCIe MRd/MWr/IORd/IOWr/Cfg TLPs into AHB-Lite master transactions
import pcie_pkg::*;

module pcie_to_ahb_bridge (
  input  logic              clk,
  input  logic              rst_n,
  // PCIe TLP request
  input  logic              req_valid,
  input  tlp_type_e         req_tlp_type,
  input  logic [63:0]       req_addr,
  input  logic [9:0]        req_length,
  input  logic [63:0]       req_data,
  input  logic [3:0]        req_first_be,
  input  logic [3:0]        req_last_be,
  input  logic [7:0]        req_tag,
  input  logic [15:0]       req_req_id,
  output logic              req_ready,
  // PCIe Completion output
  output logic              cpl_valid,
  output logic [31:0]       cpl_data,
  output logic [7:0]        cpl_tag,
  output logic [2:0]        cpl_status,
  // AHB-Lite master
  output logic              hsel,
  output logic [31:0]       haddr,
  output logic [1:0]        htrans,   // 0=IDLE 2=NONSEQ 3=SEQ
  output logic              hwrite,
  output logic [2:0]        hsize,
  output logic [2:0]        hburst,   // 0=SINGLE 3=INCR4 5=INCR8 1=INCR
  output logic [31:0]       hwdata,
  input  logic [31:0]       hrdata,
  input  logic              hready,
  input  logic [1:0]        hresp
);

  typedef enum logic [2:0] { IDLE, ADDR, DATA, CPL, UR_CPL } state_e;
  state_e state;

  logic [7:0]  tag_r;
  logic        is_write_r;
  logic [31:0] addr_r;
  logic [9:0]  beats_r, beat_cnt;
  logic [63:0] data_r;

  // HTRANS encoding
  localparam logic [1:0] HTRANS_IDLE  = 2'b00;
  localparam logic [1:0] HTRANS_NONSEQ= 2'b10;
  localparam logic [1:0] HTRANS_SEQ   = 2'b11;

  // Burst type selection based on length
  function automatic logic [2:0] burst_type(logic [9:0] len);
    if (len <= 1)  return 3'b000; // SINGLE
    if (len <= 4)  return 3'b011; // INCR4
    if (len <= 8)  return 3'b101; // INCR8
    return 3'b001;                // INCR (undefined length)
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE; req_ready <= 0; cpl_valid <= 0;
      hsel <= 0; htrans <= HTRANS_IDLE; hwrite <= 0;
      hsize <= 3'b010; hburst <= 3'b000; hwdata <= 0; haddr <= 0;
      beat_cnt <= 0;
    end else begin
      cpl_valid <= 0; req_ready <= 0;
      case (state)
        IDLE: begin
          hsel   <= 0; htrans <= HTRANS_IDLE;
          if (req_valid) begin
            req_ready  <= 1;
            tag_r      <= req_tag;
            addr_r     <= req_addr[31:0]; // AHB is 32-bit
            data_r     <= req_data;
            beats_r    <= (req_length == 0) ? 10'd1 : req_length;
            beat_cnt   <= 0;
            case (req_tlp_type)
              MWr32, MWr64, IOWr, CfgWr0, CfgWr1:
                begin is_write_r <= 1; state <= ADDR; end
              MRd32, MRd64, IORd, CfgRd0, CfgRd1:
                begin is_write_r <= 0; state <= ADDR; end
              default: state <= UR_CPL;
            endcase
          end
        end
        ADDR: begin
          req_ready <= 0;
          hsel      <= 1;
          haddr     <= addr_r;
          hwrite    <= is_write_r;
          hsize     <= 3'b010;        // 32-bit
          hburst    <= burst_type(beats_r);
          htrans    <= HTRANS_NONSEQ;
          hwdata    <= data_r[31:0];
          state     <= DATA;
        end
        DATA: begin
          if (hready) begin
            if (hresp == 2'b01) begin  // ERROR
              hsel <= 0; htrans <= HTRANS_IDLE; state <= CPL;
            end else begin
              beat_cnt <= beat_cnt + 1;
              if (beat_cnt + 1 >= beats_r) begin
                hsel <= 0; htrans <= HTRANS_IDLE; state <= CPL;
              end else begin
                haddr  <= haddr + 4;
                htrans <= HTRANS_SEQ;
                hwdata <= data_r[63:32]; // second DW from data_hi portion
              end
            end
          end
        end
        CPL: begin
          cpl_valid  <= 1;
          cpl_tag    <= tag_r;
          cpl_data   <= is_write_r ? '0 : hrdata;
          cpl_status <= (hresp == 2'b01) ? 3'h4 : 3'h0; // CA or SC
          state      <= IDLE;
        end
        UR_CPL: begin
          cpl_valid  <= 1;
          cpl_tag    <= tag_r;
          cpl_data   <= '0;
          cpl_status <= 3'h1; // UR
          state      <= IDLE;
        end
      endcase
    end
  end

endmodule : pcie_to_ahb_bridge
