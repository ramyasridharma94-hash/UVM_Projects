`ifndef UCIE_MONITOR_SV
`define UCIE_MONITOR_SV

// Monitor observes both TX acceptance (for scoreboard expected side)
// and RX output (for scoreboard actual side) in parallel threads.
class ucie_monitor extends uvm_monitor;
  `uvm_component_utils(ucie_monitor)

  virtual ucie_if.monitor_mp vif;

  // tx_ap: fires when DUT accepts a flit (tx_valid && tx_ready)
  // rx_ap: fires when DUT outputs a flit (rx_flit_valid)
  uvm_analysis_port #(ucie_seq_item) tx_ap;
  uvm_analysis_port #(ucie_seq_item) rx_ap;

  function new(string name = "ucie_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_ap = new("tx_ap", this);
    rx_ap = new("rx_ap", this);
    if (!uvm_config_db #(virtual ucie_if.monitor_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "UCIe monitor: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    fork
      monitor_tx();
      monitor_rx();
    join
  endtask

  task monitor_tx();
    ucie_seq_item item;
    forever begin
      @(vif.monitor_cb iff (vif.monitor_cb.tx_flit_valid && vif.monitor_cb.tx_flit_ready));
      item           = ucie_seq_item::type_id::create("tx_item");
      item.flit_data = vif.monitor_cb.tx_flit_data;
      item.flit_type = 2'b00;
      tx_ap.write(item);
      `uvm_info("UCIE_MON", $sformatf("TX accepted: %s", item.convert2string()), UVM_HIGH)
    end
  endtask

  task monitor_rx();
    ucie_seq_item item;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.rx_flit_valid);
      item           = ucie_seq_item::type_id::create("rx_item");
      item.flit_data = vif.monitor_cb.rx_flit_data;
      item.flit_type = 2'b00;
      rx_ap.write(item);
      `uvm_info("UCIE_MON", $sformatf("RX output:   %s", item.convert2string()), UVM_HIGH)
    end
  endtask

endclass

`endif
