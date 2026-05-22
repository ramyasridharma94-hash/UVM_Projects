`ifndef SPI_BRIDGE_MONITOR_SV
`define SPI_BRIDGE_MONITOR_SV
class spi_monitor extends uvm_monitor;
  `uvm_component_utils(spi_monitor)
  virtual spi_if.monitor_mp vif;
  uvm_analysis_port #(spi_seq_item) ap;
  function new(string name = "spi_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual spi_if.monitor_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "SPI bridge monitor: no vif")
  endfunction
  task run_phase(uvm_phase phase);
    spi_seq_item item;
    bit [7:0]    byte1, byte2;
    forever begin
      @(negedge vif.monitor_cb.cs_n);
      item  = spi_seq_item::type_id::create("item");
      byte1 = '0; byte2 = '0;
      repeat (8) begin @(posedge vif.monitor_cb.sclk); byte1 = {byte1[6:0], vif.monitor_cb.mosi}; end
      repeat (8) begin @(posedge vif.monitor_cb.sclk); byte2 = {byte2[6:0], vif.monitor_cb.mosi}; end
      @(posedge vif.monitor_cb.cs_n);
      item.op       = byte1[7] ? SPI_BR_READ : SPI_BR_WRITE;
      item.i2c_addr = byte1[6:0];
      item.data     = byte2;
      ap.write(item);
      `uvm_info("SPI_BR_MON", item.convert2string(), UVM_HIGH)
    end
  endtask
endclass
`endif
