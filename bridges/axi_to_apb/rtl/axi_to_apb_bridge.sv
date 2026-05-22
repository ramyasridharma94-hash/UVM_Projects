// AXI4-Lite to APB bridge
// State machine: IDLE -> AXI_LATCH -> APB_SETUP -> APB_ENABLE -> RESPOND
module axi_to_apb_bridge #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32
)(
  input  logic                    aclk,
  input  logic                    aresetn,
  // AXI4-Lite Slave Port
  input  logic [ADDR_WIDTH-1:0]   s_awaddr,
  input  logic                    s_awvalid,
  output logic                    s_awready,
  input  logic [DATA_WIDTH-1:0]   s_wdata,
  input  logic [DATA_WIDTH/8-1:0] s_wstrb,
  input  logic                    s_wvalid,
  output logic                    s_wready,
  output logic [1:0]              s_bresp,
  output logic                    s_bvalid,
  input  logic                    s_bready,
  input  logic [ADDR_WIDTH-1:0]   s_araddr,
  input  logic                    s_arvalid,
  output logic                    s_arready,
  output logic [DATA_WIDTH-1:0]   s_rdata,
  output logic [1:0]              s_rresp,
  output logic                    s_rvalid,
  input  logic                    s_rready,
  // APB Master Port
  output logic [ADDR_WIDTH-1:0]   m_paddr,
  output logic                    m_psel,
  output logic                    m_penable,
  output logic                    m_pwrite,
  output logic [DATA_WIDTH-1:0]   m_pwdata,
  input  logic [DATA_WIDTH-1:0]   m_prdata,
  input  logic                    m_pready,
  input  logic                    m_pslverr
);

  typedef enum logic [2:0] {
    IDLE, AXI_LATCH, APB_SETUP, APB_ENABLE, WR_RESPOND, RD_RESPOND
  } state_e;
  state_e state;

  logic                    is_write;
  logic [ADDR_WIDTH-1:0]   lat_addr;
  logic [DATA_WIDTH-1:0]   lat_wdata;
  logic [DATA_WIDTH/8-1:0] lat_wstrb;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      state      <= IDLE;
      s_awready  <= 1'b0;
      s_wready   <= 1'b0;
      s_bvalid   <= 1'b0;
      s_bresp    <= 2'b00;
      s_arready  <= 1'b0;
      s_rvalid   <= 1'b0;
      s_rdata    <= '0;
      s_rresp    <= 2'b00;
      m_psel     <= 1'b0;
      m_penable  <= 1'b0;
      m_pwrite   <= 1'b0;
      m_paddr    <= '0;
      m_pwdata   <= '0;
    end else begin
      case (state)
        IDLE: begin
          m_psel    <= 1'b0;
          m_penable <= 1'b0;
          s_awready <= 1'b1;
          s_arready <= 1'b1;
          if (s_awvalid && s_awready) begin
            lat_addr  <= s_awaddr;
            is_write  <= 1'b1;
            s_awready <= 1'b0;
            s_arready <= 1'b0;
            s_wready  <= 1'b1;
            state     <= AXI_LATCH;
          end else if (s_arvalid && s_arready) begin
            lat_addr  <= s_araddr;
            is_write  <= 1'b0;
            s_arready <= 1'b0;
            s_awready <= 1'b0;
            state     <= APB_SETUP;
          end
        end
        AXI_LATCH: begin
          if (s_wvalid && s_wready) begin
            lat_wdata <= s_wdata;
            lat_wstrb <= s_wstrb;
            s_wready  <= 1'b0;
            state     <= APB_SETUP;
          end
        end
        APB_SETUP: begin
          m_paddr   <= lat_addr;
          m_pwrite  <= is_write;
          m_pwdata  <= is_write ? lat_wdata : '0;
          m_psel    <= 1'b1;
          m_penable <= 1'b0;
          state     <= APB_ENABLE;
        end
        APB_ENABLE: begin
          m_penable <= 1'b1;
          if (m_psel && m_penable && m_pready) begin
            m_psel    <= 1'b0;
            m_penable <= 1'b0;
            if (is_write) begin
              s_bvalid <= 1'b1;
              s_bresp  <= m_pslverr ? 2'b10 : 2'b00;
              state    <= WR_RESPOND;
            end else begin
              s_rvalid <= 1'b1;
              s_rdata  <= m_prdata;
              s_rresp  <= m_pslverr ? 2'b10 : 2'b00;
              state    <= RD_RESPOND;
            end
          end
        end
        WR_RESPOND: begin
          if (s_bvalid && s_bready) begin
            s_bvalid <= 1'b0;
            state    <= IDLE;
          end
        end
        RD_RESPOND: begin
          if (s_rvalid && s_rready) begin
            s_rvalid <= 1'b0;
            state    <= IDLE;
          end
        end
      endcase
    end
  end

endmodule
