`ifndef APB_SLV_MONITOR_SV
`define APB_SLV_MONITOR_SV
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)
  virtual apb_if.monitor_mp vif;
  uvm_analysis_port #(apb_seq_item) ap;
  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if.monitor_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "APB slave monitor (bridge): no vif")
  endfunction
  task run_phase(uvm_phase phase);
    apb_seq_item item;
    forever begin
      @(vif.monitor_cb iff (vif.monitor_cb.psel && vif.monitor_cb.penable && vif.monitor_cb.pready));
      item         = apb_seq_item::type_id::create("item");
      item.op      = vif.monitor_cb.pwrite ? APB_SLV_WRITE : APB_SLV_READ;
      item.addr    = vif.monitor_cb.paddr;
      item.data    = vif.monitor_cb.pwrite ? vif.monitor_cb.pwdata : vif.monitor_cb.prdata;
      item.pslverr = vif.monitor_cb.pslverr;
      ap.write(item);
      `uvm_info("APB_SLV_MON", $sformatf("%s", item.convert2string()), UVM_HIGH)
    end
  endtask
endclass
`endif
