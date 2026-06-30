`ifndef APB_MONITOR_SV
`define APB_MONITOR_SV
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)
  virtual apb_if.monitor_mp vif;
  uvm_analysis_port #(apb_seq_item) ap_apb;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_apb = new("ap_apb", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("NOVIF", "apb_monitor: apb_vif not found")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(vif.monitor_cb);
      // Complete APB transfer: psel & penable & pready
      if (vif.monitor_cb.psel && vif.monitor_cb.penable && vif.monitor_cb.pready) begin
        apb_seq_item it = apb_seq_item::type_id::create("apb_mon");
        it.addr   = vif.monitor_cb.paddr;
        it.write  = vif.monitor_cb.pwrite;
        it.wdata  = vif.monitor_cb.pwdata;
        it.rdata  = vif.monitor_cb.prdata;
        it.strb   = vif.monitor_cb.pstrb;
        it.prot   = vif.monitor_cb.pprot;
        it.slverr = vif.monitor_cb.pslverr;
        ap_apb.write(it);
        `uvm_info("APB_MON", it.convert2string(), UVM_HIGH)
      end
    end
  endtask
endclass
`endif
