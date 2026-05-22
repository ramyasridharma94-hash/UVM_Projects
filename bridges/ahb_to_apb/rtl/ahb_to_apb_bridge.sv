// AHB-Lite to APB bridge
// Accepts NONSEQ/SEQ transfers, inserts APB setup+enable phases
module ahb_to_apb_bridge #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32
)(
  input  logic                  hclk,
  input  logic                  hresetn,
  // AHB Slave Port
  input  logic [ADDR_WIDTH-1:0] s_haddr,
  input  logic [1:0]            s_htrans,
  input  logic                  s_hwrite,
  input  logic [2:0]            s_hsize,
  input  logic [2:0]            s_hburst,
  input  logic [DATA_WIDTH-1:0] s_hwdata,
  output logic [DATA_WIDTH-1:0] s_hrdata,
  input  logic                  s_hsel,
  input  logic                  s_hready_in,
  output logic                  s_hready_out,
  output logic                  s_hresp,
  // APB Master Port
  output logic [ADDR_WIDTH-1:0] m_paddr,
  output logic                  m_psel,
  output logic                  m_penable,
  output logic                  m_pwrite,
  output logic [DATA_WIDTH-1:0] m_pwdata,
  input  logic [DATA_WIDTH-1:0] m_prdata,
  input  logic                  m_pready,
  input  logic                  m_pslverr
);

  localparam HTRANS_IDLE   = 2'b00;
  localparam HTRANS_NONSEQ = 2'b10;
  localparam HTRANS_SEQ    = 2'b11;

  typedef enum logic [2:0] {
    IDLE, AHB_SAMPLE, APB_SETUP, APB_ENABLE, WAIT_READY, RESPOND
  } state_e;
  state_e state;

  logic [ADDR_WIDTH-1:0] lat_addr;
  logic                  lat_write;
  logic [DATA_WIDTH-1:0] lat_wdata;
  logic                  active;

  assign active = s_hsel && s_hready_in &&
                  (s_htrans == HTRANS_NONSEQ || s_htrans == HTRANS_SEQ);

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      state       <= IDLE;
      s_hready_out<= 1'b1;
      s_hresp     <= 1'b0;
      s_hrdata    <= '0;
      m_psel      <= 1'b0;
      m_penable   <= 1'b0;
      m_pwrite    <= 1'b0;
      m_paddr     <= '0;
      m_pwdata    <= '0;
    end else begin
      case (state)
        IDLE: begin
          m_psel      <= 1'b0;
          m_penable   <= 1'b0;
          s_hready_out<= 1'b1;
          s_hresp     <= 1'b0;
          if (active) begin
            lat_addr    <= s_haddr;
            lat_write   <= s_hwrite;
            s_hready_out<= 1'b0;  // stall AHB
            state       <= AHB_SAMPLE;
          end
        end
        AHB_SAMPLE: begin
          // Capture write data from AHB data phase
          lat_wdata <= s_hwdata;
          m_paddr   <= lat_addr;
          m_pwrite  <= lat_write;
          m_pwdata  <= s_hwdata;
          m_psel    <= 1'b1;
          m_penable <= 1'b0;
          state     <= APB_SETUP;
        end
        APB_SETUP: begin
          m_penable <= 1'b1;
          state     <= APB_ENABLE;
        end
        APB_ENABLE: begin
          if (m_pready) begin
            m_psel      <= 1'b0;
            m_penable   <= 1'b0;
            s_hresp     <= m_pslverr;
            s_hrdata    <= m_prdata;
            s_hready_out<= 1'b1;
            state       <= IDLE;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule
