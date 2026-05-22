`ifndef SPI_BRIDGE_DRIVER_SV
`define SPI_BRIDGE_DRIVER_SV
class spi_driver extends uvm_driver #(spi_seq_item);
  `uvm_component_utils(spi_driver)
  virtual spi_if.master_mp vif;
  int SCLK_HALF = 5;
  function new(string name = "spi_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual spi_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "SPI bridge driver: no vif")
  endfunction
  task run_phase(uvm_phase phase);
    spi_seq_item req;
    vif.master_cb.cs_n <= 1; vif.master_cb.sclk <= 0; vif.master_cb.mosi <= 0;
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      drive_frame(req);
      seq_item_port.item_done();
    end
  endtask
  task send_byte(input bit [7:0] byte_out, output bit [7:0] byte_in);
    for (int i = 7; i >= 0; i--) begin
      vif.master_cb.mosi <= byte_out[i];
      #(SCLK_HALF); vif.master_cb.sclk <= 1;
      #(SCLK_HALF); byte_in[i] = vif.master_cb.miso;
      vif.master_cb.sclk <= 0;
    end
  endtask
  task drive_frame(spi_seq_item req);
    bit [7:0] rx_byte;
    // SPI frame: [15] = R/W, [14:8] = I2C addr, [7:0] = data
    bit [7:0] byte1 = {req.op == SPI_BR_READ, req.i2c_addr};
    bit [7:0] byte2 = req.data;
    @(vif.master_cb); vif.master_cb.cs_n <= 0; #(SCLK_HALF);
    send_byte(byte1, rx_byte);
    send_byte(byte2, rx_byte);
    if (req.op == SPI_BR_READ) req.data = rx_byte;
    #(SCLK_HALF); vif.master_cb.cs_n <= 1; #(SCLK_HALF*4);
  endtask
endclass
`endif
