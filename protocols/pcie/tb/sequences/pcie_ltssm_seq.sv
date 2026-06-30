`ifndef PCIE_LTSSM_SEQ_SV
`define PCIE_LTSSM_SEQ_SV

// LTSSM sequence — exercises link training, speed change, recovery, loopback
class pcie_ltssm_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_ltssm_seq)
  import pcie_pkg::*;

  virtual pcie_if vif_ltssm;

  typedef enum {
    LTSSM_TRAIN_ONLY,
    LTSSM_SPEED_CHANGE,
    LTSSM_RECOVERY,
    LTSSM_LOOPBACK,
    LTSSM_HOT_RESET,
    LTSSM_DISABLE_ENABLE
  } ltssm_scenario_e;

  rand ltssm_scenario_e scenario;

  function new(string name = "pcie_ltssm_seq");
    super.new(name);
  endfunction

  function void pre_start();
    if (!uvm_config_db #(virtual pcie_if)::get(null, get_full_name(), "pcie_vif", vif_ltssm))
      `uvm_fatal("NOVIF", "pcie_ltssm_seq: cannot get pcie_vif")
  endfunction

  task wait_ltssm(ltssm_state_e target, int timeout_cycles = 500);
    int t = 0;
    while (vif_ltssm.ltssm_state !== target && t < timeout_cycles) begin
      @(vif_ltssm.monitor_cb); t++;
    end
    if (t == timeout_cycles)
      `uvm_warning("LTSSM_TMO", $sformatf("Timeout waiting for state %s", target.name()))
    else
      `uvm_info("LTSSM_SEQ", $sformatf("Reached state: %s after %0d cycles", target.name(), t), UVM_LOW)
  endtask

  task body();
    pcie_tlp_seq_item item;
    `uvm_info("LTSSM_SEQ", $sformatf("LTSSM scenario: %s", scenario.name()), UVM_LOW)

    case (scenario)
      LTSSM_TRAIN_ONLY: begin
        // Link training already done by driver; just verify L0
        @(vif_ltssm.monitor_cb);
        `uvm_info("LTSSM_SEQ", $sformatf("Link up=%0b speed=%s width=x%0d",
                  vif_ltssm.link_up,
                  vif_ltssm.negotiated_speed.name(),
                  vif_ltssm.negotiated_width), UVM_LOW)
      end

      LTSSM_SPEED_CHANGE: begin
        // Change target speed to trigger Recovery.Speed
        `uvm_info("LTSSM_SEQ", "Changing link speed Gen1->Gen3", UVM_LOW)
        @(vif_ltssm.driver_cb);
        vif_ltssm.driver_cb.app_target_speed <= GEN3;
        wait_ltssm(LTSSM_RECOVERY_SPEED);
        wait_ltssm(LTSSM_L0);
        `uvm_info("LTSSM_SEQ", $sformatf("After speed change: %s",
                  vif_ltssm.negotiated_speed.name()), UVM_LOW)
      end

      LTSSM_RECOVERY: begin
        // Inject framing error to trigger recovery
        `uvm_info("LTSSM_SEQ", "Triggering link recovery via framing error", UVM_LOW)
        @(vif_ltssm.driver_cb);
        vif_ltssm.driver_cb.inject_framing_err <= 1;
        @(vif_ltssm.driver_cb);
        vif_ltssm.driver_cb.inject_framing_err <= 0;
        wait_ltssm(LTSSM_RECOVERY_RCVR);
        wait_ltssm(LTSSM_L0);
        `uvm_info("LTSSM_SEQ", "Link recovered to L0", UVM_LOW)
      end

      LTSSM_LOOPBACK: begin
        `uvm_info("LTSSM_SEQ", "Entering loopback mode", UVM_LOW)
        @(vif_ltssm.driver_cb);
        vif_ltssm.driver_cb.loopback_en <= 1;
        wait_ltssm(LTSSM_LOOPBACK_ACTIVE);
        // Send some TLPs in loopback
        for (int i = 0; i < 4; i++) begin
          item = pcie_tlp_seq_item::type_id::create($sformatf("lb_tlp_%0d", i));
          start_item(item);
          if (!item.randomize() with { tlp_type == MWr32; length == 1; })
            `uvm_fatal("RAND", "LTSSM loopback TLP failed")
          finish_item(item);
        end
        @(vif_ltssm.driver_cb);
        vif_ltssm.driver_cb.loopback_en <= 0;
        wait_ltssm(LTSSM_L0);
        `uvm_info("LTSSM_SEQ", "Exited loopback, back to L0", UVM_LOW)
      end

      LTSSM_DISABLE_ENABLE: begin
        `uvm_info("LTSSM_SEQ", "Disabling and re-enabling link", UVM_LOW)
        @(vif_ltssm.driver_cb);
        vif_ltssm.driver_cb.link_disable <= 1;
        wait_ltssm(LTSSM_DISABLED);
        repeat (10) @(vif_ltssm.driver_cb);
        vif_ltssm.driver_cb.link_disable <= 0;
        vif_ltssm.driver_cb.app_init_req <= 1;
        @(vif_ltssm.driver_cb);
        vif_ltssm.driver_cb.app_init_req <= 0;
        wait_ltssm(LTSSM_L0, 500);
        `uvm_info("LTSSM_SEQ", "Link re-established", UVM_LOW)
      end
    endcase
    `uvm_info("LTSSM_SEQ", "LTSSM sequence complete", UVM_LOW)
  endtask

endclass : pcie_ltssm_seq

`endif
