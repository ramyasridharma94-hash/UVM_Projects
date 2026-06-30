`ifndef AHB_MONITOR_SV
`define AHB_MONITOR_SV
class ahb_monitor extends uvm_monitor;
  `uvm_component_utils(ahb_monitor)
  virtual ahb_if.monitor_mp vif;
  uvm_analysis_port #(ahb_seq_item) ap_ahb;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_ahb = new("ap_ahb",this);
    if (!uvm_config_db #(virtual ahb_if)::get(this,"","ahb_vif",vif))
      `uvm_fatal("NOVIF","ahb_monitor: ahb_vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    logic        addr_phase = 0;
    ahb_seq_item pending;
    forever begin
      @(vif.monitor_cb);
      // Address phase: hsel & NONSEQ/SEQ
      if (vif.monitor_cb.hsel && vif.monitor_cb.htrans[1]) begin
        pending       = ahb_seq_item::type_id::create("ahb_mon");
        pending.addr  = vif.monitor_cb.haddr;
        pending.write = vif.monitor_cb.hwrite;
        pending.size  = vif.monitor_cb.hsize;
        pending.burst = vif.monitor_cb.hburst;
        pending.trans = vif.monitor_cb.htrans;
        addr_phase    = 1;
      end
      // Data phase: hready
      if (addr_phase && vif.monitor_cb.hready) begin
        pending.data = vif.monitor_cb.hwrite ? vif.monitor_cb.hwdata : vif.monitor_cb.hrdata;
        pending.resp = vif.monitor_cb.hresp;
        ap_ahb.write(pending);
        `uvm_info("AHB_MON", pending.convert2string(), UVM_HIGH)
        addr_phase = 0;
      end
    end
  endtask
endclass
`endif
