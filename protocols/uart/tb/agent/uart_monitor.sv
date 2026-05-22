`ifndef UART_MONITOR_SV
`define UART_MONITOR_SV

class uart_monitor extends uvm_monitor;
  `uvm_component_utils(uart_monitor)

  virtual uart_if.monitor_mp vif;
  uvm_analysis_port #(uart_seq_item) ap;

  function new(string name = "uart_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual uart_if.monitor_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "UART monitor: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    uart_seq_item item;
    forever begin
      // Monitor on the RX side (DUT output)
      @(vif.monitor_cb iff vif.monitor_cb.rx_valid);
      item      = uart_seq_item::type_id::create("item");
      item.data = vif.monitor_cb.rx_data;
      ap.write(item);
      `uvm_info("UART_MON", $sformatf("Received: %s", item.convert2string()), UVM_HIGH)
    end
  endtask

endclass

`endif
