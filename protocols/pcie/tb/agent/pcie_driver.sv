`ifndef PCIE_DRIVER_SV
`define PCIE_DRIVER_SV

class pcie_driver extends uvm_driver #(pcie_tlp_seq_item);
  `uvm_component_utils(pcie_driver)

  import pcie_pkg::*;

  virtual pcie_if.driver_mp vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual pcie_if)::get(this, "", "pcie_vif", vif))
      `uvm_fatal("NOVIF", "pcie_driver: cannot get pcie_vif from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    pcie_tlp_seq_item item;
    // Initialize outputs
    vif.driver_cb.req_valid        <= 0;
    vif.driver_cb.app_init_req     <= 0;
    vif.driver_cb.loopback_en      <= 0;
    vif.driver_cb.link_disable     <= 0;
    vif.driver_cb.inject_framing_err <= 0;
    vif.driver_cb.pm_enter_l1_req  <= 0;
    vif.driver_cb.rx_elec_idle     <= '1;
    vif.driver_cb.rx_valid_phy     <= 0;
    vif.driver_cb.rx_data_phy      <= '0;
    vif.driver_cb.app_target_speed <= GEN1;
    vif.driver_cb.app_target_width <= WIDTH_X1;

    // Bring up the link
    @(vif.driver_cb);
    vif.driver_cb.app_init_req     <= 1;
    vif.driver_cb.app_target_speed <= GEN3;
    vif.driver_cb.app_target_width <= WIDTH_X4;
    vif.driver_cb.rx_elec_idle     <= '0;
    @(vif.driver_cb);
    vif.driver_cb.app_init_req     <= 0;

    // Wait for link up (timeout 1000 cycles)
    fork
      begin
        wait (vif.driver_cb.link_up === 1);
      end
      begin
        repeat (1000) @(vif.driver_cb);
        `uvm_warning("LINKUP_TMO", "Link did not come up within 1000 cycles")
      end
    join_any
    disable fork;

    forever begin
      seq_item_port.get_next_item(item);
      drive_tlp(item);
      seq_item_port.item_done();
    end
  endtask

  task drive_tlp(pcie_tlp_seq_item item);
    // Error injection hooks
    if (item.inject_err == ERR_BAD_TLP || item.inject_err == ERR_BAD_DLLP)
      vif.driver_cb.inject_framing_err <= 1;
    if (item.inject_err == ERR_POISONED_TLP)
      vif.driver_cb.req_ep <= 1;

    // Assert request
    @(vif.driver_cb);
    vif.driver_cb.req_valid    <= 1;
    vif.driver_cb.req_tlp_type <= item.tlp_type;
    vif.driver_cb.req_addr     <= item.addr;
    vif.driver_cb.req_length   <= item.length[9:0];
    vif.driver_cb.req_tc       <= item.tc;
    vif.driver_cb.req_attr     <= item.attr;
    vif.driver_cb.req_req_id   <= item.req_id;
    vif.driver_cb.req_tag      <= item.tag[7:0];
    vif.driver_cb.req_first_be <= item.first_be;
    vif.driver_cb.req_last_be  <= item.last_be;
    vif.driver_cb.req_msg_code <= item.msg_code;
    vif.driver_cb.req_ep       <= item.ep;
    vif.driver_cb.req_ecrc_en  <= item.ecrc_en;
    vif.driver_cb.req_data_lo  <= item.data_lo;
    vif.driver_cb.req_data_hi  <= item.data_hi;

    // Wait for ready (up to 64 cycles)
    begin
      int timeout = 0;
      while (!vif.driver_cb.req_ready && timeout < 64) begin
        @(vif.driver_cb);
        timeout++;
      end
      if (timeout == 64)
        `uvm_warning("DRV_TMO", $sformatf("req_ready timeout for %s", item.convert2string()))
    end

    @(vif.driver_cb);
    vif.driver_cb.req_valid          <= 0;
    vif.driver_cb.inject_framing_err <= 0;
    vif.driver_cb.req_ep             <= 0;

    `uvm_info("DRV", $sformatf("Drove: %s", item.convert2string()), UVM_HIGH)
  endtask

endclass : pcie_driver

`endif
