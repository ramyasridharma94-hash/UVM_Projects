`ifndef AXI4_MONITOR_SV
`define AXI4_MONITOR_SV

class axi4_monitor extends uvm_monitor;
  `uvm_component_utils(axi4_monitor)

  virtual axi4_if.monitor_mp vif;
  uvm_analysis_port #(axi4_seq_item) ap;

  function new(string name = "axi4_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual axi4_if.monitor_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "AXI4 monitor: no virtual interface found")
  endfunction

  task run_phase(uvm_phase phase);
    fork
      collect_write_txns();
      collect_read_txns();
    join
  endtask

  task collect_write_txns();
    axi4_seq_item item;
    forever begin
      @(vif.monitor_cb iff (vif.monitor_cb.awvalid && vif.monitor_cb.awready));
      item = axi4_seq_item::type_id::create("wr_item");
      item.op    = AXI4_WRITE;
      item.id    = vif.monitor_cb.awid;
      item.addr  = vif.monitor_cb.awaddr;
      item.len   = vif.monitor_cb.awlen;
      item.size  = vif.monitor_cb.awsize;
      item.burst = vif.monitor_cb.awburst;
      item.data  = new[vif.monitor_cb.awlen + 1];
      item.strb  = new[vif.monitor_cb.awlen + 1];

      for (int i = 0; i <= item.len; i++) begin
        @(vif.monitor_cb iff (vif.monitor_cb.wvalid && vif.monitor_cb.wready));
        item.data[i] = vif.monitor_cb.wdata;
        item.strb[i] = vif.monitor_cb.wstrb;
      end

      @(vif.monitor_cb iff (vif.monitor_cb.bvalid && vif.monitor_cb.bready));
      item.resp = vif.monitor_cb.bresp;
      ap.write(item);
      `uvm_info("AXI4_MON", $sformatf("WR: %s", item.convert2string()), UVM_HIGH)
    end
  endtask

  task collect_read_txns();
    axi4_seq_item item;
    forever begin
      @(vif.monitor_cb iff (vif.monitor_cb.arvalid && vif.monitor_cb.arready));
      item = axi4_seq_item::type_id::create("rd_item");
      item.op    = AXI4_READ;
      item.id    = vif.monitor_cb.arid;
      item.addr  = vif.monitor_cb.araddr;
      item.len   = vif.monitor_cb.arlen;
      item.size  = vif.monitor_cb.arsize;
      item.burst = vif.monitor_cb.arburst;
      item.data  = new[vif.monitor_cb.arlen + 1];

      for (int i = 0; i <= item.len; i++) begin
        @(vif.monitor_cb iff (vif.monitor_cb.rvalid && vif.monitor_cb.rready));
        item.data[i] = vif.monitor_cb.rdata;
        item.resp    = vif.monitor_cb.rresp;
      end
      ap.write(item);
      `uvm_info("AXI4_MON", $sformatf("RD: %s", item.convert2string()), UVM_HIGH)
    end
  endtask

endclass

`endif
