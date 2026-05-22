// AXI4-Lite to AHB-Lite bridge (single transfers only)
module axi_to_ahb_bridge #(
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
  // AHB Master Port
  output logic [ADDR_WIDTH-1:0]   m_haddr,
  output logic [1:0]              m_htrans,  // 00=IDLE, 10=NONSEQ
  output logic                    m_hwrite,
  output logic [2:0]              m_hsize,
  output logic [2:0]              m_hburst,
  output logic [DATA_WIDTH-1:0]   m_hwdata,
  input  logic [DATA_WIDTH-1:0]   m_hrdata,
  input  logic                    m_hready,
  input  logic                    m_hresp
);

  typedef enum logic [2:0] {
    IDLE, AXI_LATCH, AHB_ADDR, AHB_DATA, WR_RESPOND, RD_RESPOND
  } state_e;
  state_e state;

  logic                  is_write;
  logic [ADDR_WIDTH-1:0] lat_addr;
  logic [DATA_WIDTH-1:0] lat_wdata;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      state     <= IDLE;
      s_awready <= 1'b0;
      s_wready  <= 1'b0;
      s_bvalid  <= 1'b0;
      s_bresp   <= 2'b00;
      s_arready <= 1'b0;
      s_rvalid  <= 1'b0;
      s_rdata   <= '0;
      s_rresp   <= 2'b00;
      m_htrans  <= 2'b00;
      m_hwrite  <= 1'b0;
      m_haddr   <= '0;
      m_hwdata  <= '0;
      m_hsize   <= 3'b010; // 32-bit
      m_hburst  <= 3'b000; // SINGLE
    end else begin
      case (state)
        IDLE: begin
          m_htrans  <= 2'b00; // IDLE
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
            state     <= AHB_ADDR;
          end
        end
        AXI_LATCH: begin
          if (s_wvalid && s_wready) begin
            lat_wdata <= s_wdata;
            s_wready  <= 1'b0;
            state     <= AHB_ADDR;
          end
        end
        AHB_ADDR: begin
          m_haddr  <= lat_addr;
          m_hwrite <= is_write;
          m_htrans <= 2'b10; // NONSEQ
          m_hsize  <= 3'b010;
          m_hburst <= 3'b000;
          state    <= AHB_DATA;
        end
        AHB_DATA: begin
          if (m_hready) begin
            m_htrans  <= 2'b00;
            m_hwdata  <= lat_wdata;
            if (!is_write) begin
              s_rdata  <= m_hrdata;
              s_rresp  <= m_hresp ? 2'b10 : 2'b00;
              s_rvalid <= 1'b1;
              state    <= RD_RESPOND;
            end else begin
              s_bresp  <= m_hresp ? 2'b10 : 2'b00;
              s_bvalid <= 1'b1;
              state    <= WR_RESPOND;
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
