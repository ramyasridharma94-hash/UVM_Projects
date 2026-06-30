`ifndef AXI4_MONITOR_SV
`define AXI4_MONITOR_SV
class axi4_monitor extends uvm_monitor;
  `uvm_component_utils(axi4_monitor)
  virtual axi4_if.monitor_mp vif;
  uvm_analysis_port #(axi4_seq_item) ap_axi;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_axi=new("ap_axi",this);
    if (!uvm_config_db #(virtual axi4_if)::get(this,"","axi4_vif",vif))
      `uvm_fatal("NOVIF","axi4_monitor: axi4_vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    fork
      // Monitor writes: AW then W then B
      forever begin
        axi4_seq_item it;
        @(vif.monitor_cb); if (!vif.monitor_cb.awvalid||!vif.monitor_cb.awready) continue;
        it=axi4_seq_item::type_id::create("wr"); it.is_write=1;
        it.addr=vif.monitor_cb.awaddr; it.len=vif.monitor_cb.awlen; it.id=vif.monitor_cb.awid;
        // Wait for B
        while (!(vif.monitor_cb.bvalid&&vif.monitor_cb.bready)) @(vif.monitor_cb);
        it.resp=vif.monitor_cb.bresp; ap_axi.write(it);
        `uvm_info("AXI4_MON",it.convert2string(),UVM_HIGH)
      end
      // Monitor reads: AR then R
      forever begin
        axi4_seq_item it;
        @(vif.monitor_cb); if (!vif.monitor_cb.arvalid||!vif.monitor_cb.arready) continue;
        it=axi4_seq_item::type_id::create("rd"); it.is_write=0;
        it.addr=vif.monitor_cb.araddr; it.len=vif.monitor_cb.arlen; it.id=vif.monitor_cb.arid;
        while (!(vif.monitor_cb.rvalid&&vif.monitor_cb.rlast)) @(vif.monitor_cb);
        it.data=vif.monitor_cb.rdata; it.resp=vif.monitor_cb.rresp; ap_axi.write(it);
        `uvm_info("AXI4_MON",it.convert2string(),UVM_HIGH)
      end
    join
  endtask
endclass
`endif
