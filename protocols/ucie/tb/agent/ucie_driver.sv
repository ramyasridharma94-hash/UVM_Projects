`ifndef UCIE_DRIVER_SV
`define UCIE_DRIVER_SV

class ucie_driver extends uvm_driver #(ucie_seq_item);
  `uvm_component_utils(ucie_driver)

  virtual ucie_if.master_mp vif;

  function new(string name = "ucie_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ucie_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "UCIe driver: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    ucie_seq_item req;
    vif.master_cb.tx_flit_data  <= '0;
    vif.master_cb.tx_flit_valid <= 1'b0;
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      drive_flit(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_flit(ucie_seq_item req);
    // Wait until DUT TX FIFO has room (credit available from RX)
    @(vif.master_cb iff vif.master_cb.tx_flit_ready);
    vif.master_cb.tx_flit_data  <= req.flit_data;
    vif.master_cb.tx_flit_valid <= 1'b1;
    @(vif.master_cb);
    vif.master_cb.tx_flit_valid <= 1'b0;
    `uvm_info("UCIE_DRV", $sformatf("Sent: %s", req.convert2string()), UVM_HIGH)
  endtask

endclass

`endif
