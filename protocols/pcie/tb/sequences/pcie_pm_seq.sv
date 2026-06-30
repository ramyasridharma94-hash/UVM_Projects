`ifndef PCIE_PM_SEQ_SV
`define PCIE_PM_SEQ_SV

// Power Management sequence — ASPM L0s, L1, D0/D1/D2/D3hot transitions + PME
class pcie_pm_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_pm_seq)
  import pcie_pkg::*;

  virtual pcie_if vif_pm;  // direct handle for PM-specific signals

  function new(string name = "pcie_pm_seq");
    super.new(name);
  endfunction

  function void pre_start();
    if (!uvm_config_db #(virtual pcie_if)::get(null, get_full_name(), "pcie_vif", vif_pm))
      `uvm_fatal("NOVIF", "pcie_pm_seq: cannot get pcie_vif")
  endfunction

  task body();
    pcie_tlp_seq_item item;

    // Phase 1: Send traffic in D0/L0
    `uvm_info("PM_SEQ", "Phase 1: Normal traffic in L0", UVM_LOW)
    for (int i = 0; i < 4; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("pm_pre_%0d", i));
      start_item(item);
      if (!item.randomize() with { tlp_type inside {MWr32, MRd32}; length inside {[1:4]}; })
        `uvm_fatal("RAND", "pcie_pm_seq: pre-PM randomize failed")
      finish_item(item);
    end

    // Phase 2: Enter L1 via PM DLLP
    `uvm_info("PM_SEQ", "Phase 2: Requesting ASPM L1", UVM_LOW)
    @(vif_pm.driver_cb);
    vif_pm.driver_cb.pm_enter_l1_req <= 1;
    // Wait for PM ACK (up to 50 cycles)
    begin
      int t = 0;
      while (!vif_pm.driver_cb.pm_ack && t < 50) begin
        @(vif_pm.driver_cb); t++;
      end
      if (t == 50)
        `uvm_warning("PM_SEQ", "No PM ACK within 50 cycles")
      else
        `uvm_info("PM_SEQ", "PM ACK received — entering L1", UVM_LOW)
    end
    @(vif_pm.driver_cb);
    vif_pm.driver_cb.pm_enter_l1_req <= 0;

    // Phase 3: Stay in L1 for 20 cycles
    `uvm_info("PM_SEQ", "Phase 3: Waiting in L1 for 20 cycles", UVM_LOW)
    repeat (20) @(vif_pm.driver_cb);

    // Phase 4: Exit L1 — send new traffic to trigger recovery
    `uvm_info("PM_SEQ", "Phase 4: Exiting L1 via new request", UVM_LOW)
    item = pcie_tlp_seq_item::type_id::create("pm_exit");
    start_item(item);
    if (!item.randomize() with { tlp_type == MRd32; length == 1; })
      `uvm_fatal("RAND", "pcie_pm_seq: exit randomize failed")
    finish_item(item);

    // Phase 5: PME — send PME Message TLP
    `uvm_info("PM_SEQ", "Phase 5: Sending PME Message", UVM_LOW)
    item = pcie_tlp_seq_item::type_id::create("pme_msg");
    start_item(item);
    if (!item.randomize() with {
        tlp_type  == Msg;
        msg_code  == 3'h3;   // PME message code
        tc        == 3'h0;
    })
      `uvm_fatal("RAND", "pcie_pm_seq: PME msg randomize failed")
    finish_item(item);
    `uvm_info("PM_SEQ", "Power management sequence complete", UVM_LOW)
  endtask

endclass : pcie_pm_seq

`endif
