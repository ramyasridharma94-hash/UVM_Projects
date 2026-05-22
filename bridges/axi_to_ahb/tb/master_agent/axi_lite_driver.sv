`ifndef AXI_LITE_DRIVER_SV
`define AXI_LITE_DRIVER_SV
class axi_lite_driver extends uvm_driver #(axi_lite_seq_item);
  `uvm_component_utils(axi_lite_driver)
  virtual axi_lite_if.master_mp vif;
  function new(string name = "axi_lite_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual axi_lite_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "AXI-Lite driver (bridge): no vif")
  endfunction
  task run_phase(uvm_phase phase);
    axi_lite_seq_item req;
    // Reset
    vif.master_cb.awvalid <= 0; vif.master_cb.wvalid  <= 0;
    vif.master_cb.bready  <= 1; vif.master_cb.arvalid <= 0;
    vif.master_cb.rready  <= 1;
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.op == AXIL_WRITE) begin
        fork
          begin @(vif.master_cb); vif.master_cb.awaddr <= req.addr; vif.master_cb.awvalid <= 1;
                @(vif.master_cb iff vif.master_cb.awready); vif.master_cb.awvalid <= 0; end
          begin @(vif.master_cb); vif.master_cb.wdata <= req.data; vif.master_cb.wstrb <= req.strb;
                vif.master_cb.wvalid <= 1; @(vif.master_cb iff vif.master_cb.wready);
                vif.master_cb.wvalid <= 0; end
        join
        @(vif.master_cb iff vif.master_cb.bvalid);
        req.resp = vif.master_cb.bresp;
      end else begin
        @(vif.master_cb); vif.master_cb.araddr <= req.addr; vif.master_cb.arvalid <= 1;
        @(vif.master_cb iff vif.master_cb.arready); vif.master_cb.arvalid <= 0;
        @(vif.master_cb iff vif.master_cb.rvalid);
        req.data = vif.master_cb.rdata; req.resp = vif.master_cb.rresp;
      end
      seq_item_port.item_done();
    end
  endtask
endclass
`endif
