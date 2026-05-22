`ifndef I2C_BRIDGE_MONITOR_SV
`define I2C_BRIDGE_MONITOR_SV
class i2c_monitor extends uvm_monitor;
  `uvm_component_utils(i2c_monitor)
  virtual i2c_if.monitor_mp vif;
  uvm_analysis_port #(i2c_seq_item) ap;
  function new(string name = "i2c_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual i2c_if.monitor_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "I2C bridge monitor: no vif")
  endfunction
  task run_phase(uvm_phase phase);
    i2c_seq_item item;
    bit          prev_scl, prev_sda;
    bit [7:0]    addr_byte, data_byte;
    forever begin
      @(vif.monitor_cb); prev_scl = vif.monitor_cb.scl; prev_sda = vif.monitor_cb.sda;
      @(vif.monitor_cb);
      if (prev_scl && vif.monitor_cb.scl && prev_sda && !vif.monitor_cb.sda) begin
        // START detected
        item      = i2c_seq_item::type_id::create("item");
        addr_byte = '0;
        repeat (8) begin @(posedge vif.monitor_cb.scl); addr_byte = {addr_byte[6:0], vif.monitor_cb.sda}; end
        item.op        = addr_byte[0] ? I2C_BR_READ : I2C_BR_WRITE;
        item.slave_addr= addr_byte[7:1];
        @(negedge vif.monitor_cb.scl); // skip ACK
        data_byte = '0;
        repeat (8) begin @(posedge vif.monitor_cb.scl); data_byte = {data_byte[6:0], vif.monitor_cb.sda}; end
        item.data = data_byte;
        ap.write(item);
        `uvm_info("I2C_BR_MON", item.convert2string(), UVM_HIGH)
      end
    end
  endtask
endclass
`endif
