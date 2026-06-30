`ifndef APB_PCIE_TLP_MONITOR_SV
`define APB_PCIE_TLP_MONITOR_SV

class pcie_tlp_monitor extends uvm_monitor;
  `uvm_component_utils(pcie_tlp_monitor)
  import pcie_pkg::*;

  virtual pcie_tlp_if.monitor_mp vif;
  uvm_analysis_port #(pcie_tlp_seq_item) ap_req;
  uvm_analysis_port #(pcie_tlp_seq_item) ap_cpl;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_req = new("ap_req", this);
    ap_cpl = new("ap_cpl", this);
    if (!uvm_config_db #(virtual pcie_tlp_if)::get(this, "", "pcie_tlp_vif", vif))
      `uvm_fatal("NOVIF", "pcie_tlp_monitor: pcie_tlp_vif not found")
  endfunction

  task run_phase(uvm_phase phase);
    fork mon_req(); mon_cpl(); join
  endtask

  task mon_req();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.req_valid && vif.monitor_cb.req_ready) begin
        pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create("mon_req");
        it.tlp_type  = vif.monitor_cb.req_tlp_type;
        it.addr      = vif.monitor_cb.req_addr;
        it.length    = vif.monitor_cb.req_length;
        it.tag       = vif.monitor_cb.req_tag;
        it.req_id    = vif.monitor_cb.req_req_id;
        it.first_be  = vif.monitor_cb.req_first_be;
        it.data      = vif.monitor_cb.req_data;
        ap_req.write(it);
        `uvm_info("MON_REQ", it.convert2string(), UVM_HIGH)
      end
    end
  endtask

  task mon_cpl();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.cpl_valid) begin
        pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create("mon_cpl");
        it.tag  = vif.monitor_cb.cpl_tag;
        it.data = vif.monitor_cb.cpl_data;
        ap_cpl.write(it);
        `uvm_info("MON_CPL", $sformatf("cpl tag=0x%02h data=0x%08h status=%0h",
                  it.tag, it.data, vif.monitor_cb.cpl_status), UVM_MEDIUM)
      end
    end
  endtask
endclass

`endif
