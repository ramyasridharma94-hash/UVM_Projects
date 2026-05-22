`ifndef AHB_SLV_MONITOR_SV
`define AHB_SLV_MONITOR_SV
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
      `uvm_fatal("CFG", "AHB slave monitor (bridge): no vif")
  endfunction
  task run_phase(uvm_phase phase);
    ahb_seq_item item;
    logic [31:0] lat_addr;
    logic        lat_write;
    forever begin
      @(vif.monitor_cb iff (vif.monitor_cb.hready &&
                            (vif.monitor_cb.htrans == 2'b10 || vif.monitor_cb.htrans == 2'b11)));
      lat_addr  = vif.monitor_cb.haddr;
      lat_write = vif.monitor_cb.hwrite;
      @(vif.monitor_cb iff vif.monitor_cb.hready);
      item       = ahb_seq_item::type_id::create("item");
      item.op    = lat_write ? AHB_SLV_WRITE : AHB_SLV_READ;
      item.addr  = lat_addr;
      item.data  = lat_write ? vif.monitor_cb.hwdata : vif.monitor_cb.hrdata;
      item.hresp = vif.monitor_cb.hresp;
      ap.write(item);
      `uvm_info("AHB_SLV_MON", item.convert2string(), UVM_HIGH)
    end
  endtask
endclass
`endif
