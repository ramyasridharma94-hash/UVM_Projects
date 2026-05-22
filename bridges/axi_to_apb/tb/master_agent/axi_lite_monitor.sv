`ifndef AXI_LITE_MONITOR_SV
`define AXI_LITE_MONITOR_SV
class axi_lite_monitor extends uvm_monitor;
  `uvm_component_utils(axi_lite_monitor)
  virtual axi_lite_if.monitor_mp vif;
  uvm_analysis_port #(axi_lite_seq_item) ap;
  function new(string name = "axi_lite_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual axi_lite_if.monitor_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "AXI-Lite monitor (bridge): no vif")
  endfunction
  task run_phase(uvm_phase phase);
    fork collect_write(); collect_read(); join
  endtask
  task collect_write();
    axi_lite_seq_item item;
    forever begin
      @(vif.monitor_cb iff (vif.monitor_cb.awvalid && vif.monitor_cb.awready));
      item = axi_lite_seq_item::type_id::create("wr");
      item.op = AXIL_WRITE; item.addr = vif.monitor_cb.awaddr;
      @(vif.monitor_cb iff (vif.monitor_cb.wvalid && vif.monitor_cb.wready));
      item.data = vif.monitor_cb.wdata; item.strb = vif.monitor_cb.wstrb;
      @(vif.monitor_cb iff (vif.monitor_cb.bvalid && vif.monitor_cb.bready));
      item.resp = vif.monitor_cb.bresp; ap.write(item);
    end
  endtask
  task collect_read();
    axi_lite_seq_item item;
    forever begin
      @(vif.monitor_cb iff (vif.monitor_cb.arvalid && vif.monitor_cb.arready));
      item = axi_lite_seq_item::type_id::create("rd");
      item.op = AXIL_READ; item.addr = vif.monitor_cb.araddr;
      @(vif.monitor_cb iff (vif.monitor_cb.rvalid && vif.monitor_cb.rready));
      item.data = vif.monitor_cb.rdata; item.resp = vif.monitor_cb.rresp; ap.write(item);
    end
  endtask
endclass
`endif
