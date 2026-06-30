`ifndef AHB_PCIE_TLP_DRIVER_SV
`define AHB_PCIE_TLP_DRIVER_SV
class pcie_tlp_driver extends uvm_driver #(pcie_tlp_seq_item);
  `uvm_component_utils(pcie_tlp_driver)
  import pcie_pkg::*;
  virtual pcie_tlp_if.driver_mp vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual pcie_tlp_if)::get(this,"","pcie_tlp_vif",vif))
      `uvm_fatal("NOVIF","pcie_tlp_driver: pcie_tlp_vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    pcie_tlp_seq_item item;
    vif.driver_cb.req_valid <= 0;
    forever begin
      seq_item_port.get_next_item(item);
      @(vif.driver_cb);
      vif.driver_cb.req_valid    <= 1;
      vif.driver_cb.req_tlp_type <= item.tlp_type;
      vif.driver_cb.req_addr     <= item.addr;
      vif.driver_cb.req_length   <= item.length;
      vif.driver_cb.req_data     <= item.data;
      vif.driver_cb.req_first_be <= item.first_be;
      vif.driver_cb.req_last_be  <= item.last_be;
      vif.driver_cb.req_tag      <= item.tag;
      vif.driver_cb.req_req_id   <= item.req_id;
      begin int t=0; while(!vif.driver_cb.req_ready&&t<32) begin @(vif.driver_cb);t++; end end
      @(vif.driver_cb); vif.driver_cb.req_valid <= 0;
      seq_item_port.item_done();
    end
  endtask
endclass
`endif
