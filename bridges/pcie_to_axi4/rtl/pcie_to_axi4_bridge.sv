// PCIe-to-AXI4 Bridge RTL
// Translates PCIe MRd/MWr/Cfg TLPs into AXI4 master transactions (128-bit data bus)
import pcie_pkg::*;

module pcie_to_axi4_bridge (
  input  logic              clk,
  input  logic              rst_n,
  // PCIe TLP request
  input  logic              req_valid,
  input  tlp_type_e         req_tlp_type,
  input  logic [63:0]       req_addr,
  input  logic [9:0]        req_length,
  input  logic [2:0]        req_tc,
  input  logic [1:0]        req_attr,
  input  logic [15:0]       req_req_id,
  input  logic [7:0]        req_tag,
  input  logic [3:0]        req_first_be,
  input  logic [3:0]        req_last_be,
  input  logic              req_ep,
  input  logic [63:0]       req_data_lo,
  input  logic [63:0]       req_data_hi,
  output logic              req_ready,
  // PCIe Completion output
  output logic              cpl_valid,
  output logic [63:0]       cpl_data,
  output logic [7:0]        cpl_tag,
  output logic [2:0]        cpl_status,
  // AXI4 Write Address Channel
  output logic              awvalid,
  input  logic              awready,
  output logic [63:0]       awaddr,
  output logic [7:0]        awlen,
  output logic [2:0]        awsize,
  output logic [1:0]        awburst,
  output logic [7:0]        awid,
  output logic [2:0]        awprot,
  output logic [3:0]        awcache,
  // AXI4 Write Data Channel
  output logic              wvalid,
  input  logic              wready,
  output logic [127:0]      wdata,
  output logic [15:0]       wstrb,
  output logic              wlast,
  // AXI4 Write Response Channel
  input  logic              bvalid,
  output logic              bready,
  input  logic [1:0]        bresp,
  input  logic [7:0]        bid,
  // AXI4 Read Address Channel
  output logic              arvalid,
  input  logic              arready,
  output logic [63:0]       araddr,
  output logic [7:0]        arlen,
  output logic [2:0]        arsize,
  output logic [1:0]        arburst,
  output logic [7:0]        arid,
  output logic [2:0]        arprot,
  output logic [3:0]        arcache,
  // AXI4 Read Data Channel
  input  logic              rvalid,
  output logic              rready,
  input  logic [127:0]      rdata,
  input  logic [1:0]        rresp,
  input  logic [7:0]        rid,
  input  logic              rlast
);

  typedef enum logic [2:0] { IDLE, AW, W, B_WAIT, AR, R_WAIT, CPL, UR_CPL } state_e;
  state_e state;

  logic [7:0]  tag_r;
  logic [63:0] addr_r;
  logic [7:0]  awlen_r;
  logic [127:0] wdata_r;
  logic [15:0]  wstrb_r;
  logic        is_write_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE; req_ready <= 0; cpl_valid <= 0;
      awvalid <= 0; wvalid <= 0; bready <= 0;
      arvalid <= 0; rready <= 0;
    end else begin
      cpl_valid <= 0; req_ready <= 0;

      case (state)
        IDLE: begin
          awvalid <= 0; wvalid <= 0; arvalid <= 0;
          if (req_valid) begin
            req_ready <= 1;
            tag_r     <= req_tag;
            addr_r    <= req_addr;
            awlen_r   <= (req_length == 0) ? 8'd0 : req_length - 1;
            wdata_r   <= {req_data_hi, req_data_lo};
            // Map first_be/last_be to 128-bit wstrb
            wstrb_r   <= {{8{req_last_be[3]}},{8{req_last_be[2]}},
                          {8{req_first_be[1]}},{8{req_first_be[0]}}};
            case (req_tlp_type)
              MWr32, MWr64, IOWr, CfgWr0, CfgWr1:
                begin is_write_r <= 1; state <= AW; end
              MRd32, MRd64, IORd, CfgRd0, CfgRd1:
                begin is_write_r <= 0; state <= AR; end
              default: state <= UR_CPL;
            endcase
          end
        end

        AW: begin
          req_ready <= 0;
          awvalid   <= 1;
          awaddr    <= addr_r;
          awlen     <= awlen_r;
          awsize    <= 3'b100;    // 16 bytes (128-bit)
          awburst   <= 2'b01;    // INCR
          awid      <= tag_r;
          awprot    <= 3'b010;
          awcache   <= 4'b0011;
          if (awready) begin
            awvalid <= 0;
            wvalid  <= 1;
            wdata   <= wdata_r;
            wstrb   <= wstrb_r;
            wlast   <= 1;
            state   <= W;
          end
        end

        W: begin
          if (wready) begin
            wvalid <= 0; wlast <= 0;
            bready <= 1;
            state  <= B_WAIT;
          end
        end

        B_WAIT: begin
          if (bvalid) begin
            bready    <= 0;
            cpl_valid <= 1;
            cpl_tag   <= tag_r;
            cpl_data  <= '0;
            cpl_status<= (bresp == 2'b00) ? 3'h0 : 3'h4; // OKAY→SC, else CA
            state     <= IDLE;
          end
        end

        AR: begin
          req_ready <= 0;
          arvalid   <= 1;
          araddr    <= addr_r;
          arlen     <= awlen_r;
          arsize    <= 3'b100;
          arburst   <= 2'b01;
          arid      <= tag_r;
          arprot    <= 3'b010;
          arcache   <= 4'b0011;
          if (arready) begin
            arvalid <= 0;
            rready  <= 1;
            state   <= R_WAIT;
          end
        end

        R_WAIT: begin
          if (rvalid && rlast) begin
            rready    <= 0;
            cpl_valid <= 1;
            cpl_tag   <= tag_r;
            cpl_data  <= rdata[63:0];
            cpl_status<= (rresp == 2'b00) ? 3'h0 : 3'h4;
            state     <= IDLE;
          end
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

endmodule : pcie_to_axi4_bridge
