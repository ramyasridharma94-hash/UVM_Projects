`ifndef SPI_MONITOR_SV
`define SPI_MONITOR_SV

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
      `uvm_fatal("CFG", "SPI monitor: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    spi_seq_item item;
    bit [7:0]    byte_buf;
    bit [7:0]    addr_byte;
    int          byte_cnt;

    forever begin
      // Wait for CS_N assertion
      @(negedge vif.monitor_cb.cs_n);
      item     = spi_seq_item::type_id::create("item");
      byte_cnt = 0;

      // Capture address byte
      repeat (8) begin
        @(posedge vif.monitor_cb.sclk);
        addr_byte = {addr_byte[6:0], vif.monitor_cb.mosi};
      end
      item.op   = addr_byte[7] ? SPI_READ : SPI_WRITE;
      item.addr = addr_byte[6:0];

      // Capture data bytes until CS_N deasserted
      while (!vif.monitor_cb.cs_n) begin
        byte_buf = '0;
        for (int i = 7; i >= 0; i--) begin
          @(posedge vif.monitor_cb.sclk);
          if (item.op == SPI_WRITE)
            byte_buf[i] = vif.monitor_cb.mosi;
          else
            byte_buf[i] = vif.monitor_cb.miso;
          if (vif.monitor_cb.cs_n) break;
        end
        if (!vif.monitor_cb.cs_n || i < 0) begin
          item.data = new[item.data.size()+1](item.data);
          item.data[item.data.size()-1] = byte_buf;
        end
      end

      @(posedge vif.monitor_cb.cs_n);
      ap.write(item);
      `uvm_info("SPI_MON", $sformatf("%s", item.convert2string()), UVM_HIGH)
    end
  endtask

endclass

`endif
