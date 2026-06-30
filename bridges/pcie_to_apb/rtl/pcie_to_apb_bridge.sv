// PCIe-to-APB Bridge RTL
// Translates PCIe CfgRd0/CfgWr0/MRd32/MWr32 TLPs into APB transactions
import pcie_pkg::*;

module pcie_to_apb_bridge (
  input  logic              clk,
  input  logic              rst_n,
  // PCIe TLP request (from TB master agent)
  input  logic              req_valid,
  input  tlp_type_e         req_tlp_type,
  input  logic [31:0]       req_addr,
  input  logic [9:0]        req_length,   // must be 1 for APB
  input  logic [31:0]       req_data,
  input  logic [7:0]        req_tag,
  input  logic [15:0]       req_req_id,
  input  logic [3:0]        req_first_be,
  output logic              req_ready,
  // PCIe Completion output
  output logic              cpl_valid,
  output logic [31:0]       cpl_data,
  output logic [7:0]        cpl_tag,
  output logic [2:0]        cpl_status,   // 0=SC, 4=CA, 1=UR
  // APB master
  output logic              psel,
  output logic              penable,
  output logic              pwrite,
  output logic [31:0]       paddr,
  output logic [31:0]       pwdata,
  output logic [3:0]        pstrb,
  output logic [2:0]        pprot,
  input  logic [31:0]       prdata,
  input  logic              pready,
  input  logic              pslverr
);

  typedef enum logic [2:0] {
    IDLE, DECODE, SETUP, ENABLE, CPL, UR_CPL
  } state_e;

  state_e state;
  logic [7:0]  tag_r;
  logic        is_write_r;
  logic [31:0] addr_r;
  logic [31:0] wdata_r;
  logic [3:0]  strb_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      req_ready <= 0;
      cpl_valid <= 0;
      psel      <= 0;
      penable   <= 0;
      pwrite    <= 0;
      paddr     <= '0;
      pwdata    <= '0;
      pstrb     <= '0;
      pprot     <= '0;
    end else begin
      cpl_valid <= 0;
      req_ready <= 0;

      case (state)
        IDLE: begin
          if (req_valid) begin
            req_ready <= 1;
            tag_r     <= req_tag;
            addr_r    <= req_addr;
            wdata_r   <= req_data;
            strb_r    <= req_first_be;
            case (req_tlp_type)
              MWr32, CfgWr0: begin is_write_r <= 1; state <= SETUP; end
              MRd32, CfgRd0: begin is_write_r <= 0; state <= SETUP; end
              default:        state <= UR_CPL;  // unsupported → UR
            endcase
          end
        end

        SETUP: begin
          req_ready <= 0;
          psel      <= 1;
          penable   <= 0;
          pwrite    <= is_write_r;
          paddr     <= addr_r;
          pwdata    <= wdata_r;
          pstrb     <= is_write_r ? strb_r : 4'hF;
          pprot     <= 3'b010;  // non-secure data
          state     <= ENABLE;
        end

        ENABLE: begin
          penable <= 1;
          if (pready) begin
            psel    <= 0;
            penable <= 0;
            state   <= CPL;
          end
        end

        CPL: begin
          cpl_valid  <= 1;
          cpl_tag    <= tag_r;
          cpl_data   <= is_write_r ? '0 : prdata;
          cpl_status <= pslverr ? 3'h4 : 3'h0;  // CA or SC
          state      <= IDLE;
        end

        UR_CPL: begin
          cpl_valid  <= 1;
          cpl_tag    <= tag_r;
          cpl_data   <= '0;
          cpl_status <= 3'h1;  // UR
          state      <= IDLE;
        end
      endcase
    end
  end

endmodule : pcie_to_apb_bridge
