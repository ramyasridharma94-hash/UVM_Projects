`ifndef AHB_MONITOR_SV
`define AHB_MONITOR_SV

class ahb_monitor extends uvm_monitor;
  `uvm_component_utils(ahb_monitor)

  virtual ahb_if.monitor_mp vif;
  uvm_analysis_port #(ahb_seq_item) ap;

  function new(string name = "ahb_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual ahb_if.monitor_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "AHB monitor: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    ahb_seq_item item;
    logic [31:0] lat_addr;
    logic        lat_write;
    forever begin
      @(vif.monitor_cb iff (vif.monitor_cb.hsel &&
                            vif.monitor_cb.hready &&
                            (vif.monitor_cb.htrans == 2'b10 ||
                             vif.monitor_cb.htrans == 2'b11)));
      item       = ahb_seq_item::type_id::create("item");
      item.op    = vif.monitor_cb.hwrite ? AHB_WRITE : AHB_READ;
      item.addr  = vif.monitor_cb.haddr;
      item.size  = vif.monitor_cb.hsize;
      item.burst = vif.monitor_cb.hburst;
      item.data  = new[1];

      // Data phase
      @(vif.monitor_cb iff vif.monitor_cb.hready);
      if (item.op == AHB_WRITE)
        item.data[0] = vif.monitor_cb.hwdata;
      else
        item.data[0] = vif.monitor_cb.hrdata;
      item.hresp = vif.monitor_cb.hresp;

      ap.write(item);
      `uvm_info("AHB_MON", $sformatf("%s", item.convert2string()), UVM_HIGH)
    end
  endtask

endclass

`endif
