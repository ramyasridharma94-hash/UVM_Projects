`ifndef SPI_DRIVER_SV
`define SPI_DRIVER_SV

class spi_driver extends uvm_driver #(spi_seq_item);
  `uvm_component_utils(spi_driver)

  virtual spi_if.master_mp vif;
  int sclk_half_period = 5; // ns half-period in simulation time units

  function new(string name = "spi_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual spi_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "SPI driver: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    spi_seq_item req;
    reset_signals();
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      drive_frame(req);
      seq_item_port.item_done();
    end
  endtask

  task reset_signals();
    vif.master_cb.cs_n <= 1;
    vif.master_cb.sclk <= 0;
    vif.master_cb.mosi <= 0;
  endtask

  // Send one byte MSB first, sample MISO on rising SCLK
  task send_byte(input bit [7:0] byte_out, output bit [7:0] byte_in);
    for (int i = 7; i >= 0; i--) begin
      vif.master_cb.mosi <= byte_out[i];
      #(sclk_half_period);
      vif.master_cb.sclk <= 1;
      #(sclk_half_period);
      byte_in[i] = vif.master_cb.miso;
      vif.master_cb.sclk <= 0;
    end
  endtask

  task drive_frame(spi_seq_item req);
    bit [7:0] rx_byte;
    bit [7:0] addr_byte;
    addr_byte = {req.op == SPI_READ, req.addr}; // bit7=R/W, bits[6:0]=addr

    // Assert CS_N
    @(vif.master_cb);
    vif.master_cb.cs_n <= 0;
    #(sclk_half_period);

    // Send address byte
    send_byte(addr_byte, rx_byte);

    // Send/receive data bytes
    foreach (req.data[i]) begin
      if (req.op == SPI_WRITE)
        send_byte(req.data[i], rx_byte);
      else begin
        send_byte(8'hFF, rx_byte); // dummy byte for read
        req.data[i] = rx_byte;
      end
    end

    // Deassert CS_N
    #(sclk_half_period);
    vif.master_cb.cs_n <= 1;
    #(sclk_half_period * 2);
  endtask

endclass

`endif
