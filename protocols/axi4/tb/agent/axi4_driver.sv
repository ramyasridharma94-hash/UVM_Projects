`ifndef AXI4_DRIVER_SV
`define AXI4_DRIVER_SV

class axi4_driver extends uvm_driver #(axi4_seq_item);
  `uvm_component_utils(axi4_driver)

  virtual axi4_if.master_mp vif;

  function new(string name = "axi4_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual axi4_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "AXI4 driver: no virtual interface found")
  endfunction

  task run_phase(uvm_phase phase);
    axi4_seq_item req;
    reset_signals();
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.op == AXI4_WRITE)
        do_write(req);
      else
        do_read(req);
      seq_item_port.item_done();
    end
  endtask

  task reset_signals();
    vif.master_cb.awvalid <= 0; vif.master_cb.wvalid  <= 0;
    vif.master_cb.bready  <= 1; vif.master_cb.arvalid <= 0;
    vif.master_cb.rready  <= 1;
    vif.master_cb.awid    <= 0; vif.master_cb.awaddr  <= 0;
    vif.master_cb.awlen   <= 0; vif.master_cb.awsize  <= 0;
    vif.master_cb.awburst <= 0;
    vif.master_cb.wdata   <= 0; vif.master_cb.wstrb   <= 0;
    vif.master_cb.wlast   <= 0;
    vif.master_cb.arid    <= 0; vif.master_cb.araddr  <= 0;
    vif.master_cb.arlen   <= 0; vif.master_cb.arsize  <= 0;
    vif.master_cb.arburst <= 0;
  endtask

  task do_write(axi4_seq_item req);
    // Write Address channel
    @(vif.master_cb);
    vif.master_cb.awid    <= req.id;
    vif.master_cb.awaddr  <= req.addr;
    vif.master_cb.awlen   <= req.len;
    vif.master_cb.awsize  <= req.size;
    vif.master_cb.awburst <= req.burst;
    vif.master_cb.awvalid <= 1;
    @(vif.master_cb iff vif.master_cb.awready);
    vif.master_cb.awvalid <= 0;

    // Write Data channel
    foreach (req.data[i]) begin
      @(vif.master_cb);
      vif.master_cb.wdata  <= req.data[i];
      vif.master_cb.wstrb  <= req.strb[i];
      vif.master_cb.wlast  <= (i == req.data.size()-1);
      vif.master_cb.wvalid <= 1;
      @(vif.master_cb iff vif.master_cb.wready);
    end
    vif.master_cb.wvalid <= 0;
    vif.master_cb.wlast  <= 0;

    // Write Response
    @(vif.master_cb iff vif.master_cb.bvalid);
    req.resp = vif.master_cb.bresp;
  endtask

  task do_read(axi4_seq_item req);
    // Read Address channel
    @(vif.master_cb);
    vif.master_cb.arid    <= req.id;
    vif.master_cb.araddr  <= req.addr;
    vif.master_cb.arlen   <= req.len;
    vif.master_cb.arsize  <= req.size;
    vif.master_cb.arburst <= req.burst;
    vif.master_cb.arvalid <= 1;
    @(vif.master_cb iff vif.master_cb.arready);
    vif.master_cb.arvalid <= 0;

    // Read Data channel
    req.data = new[req.len+1];
    for (int i = 0; i <= req.len; i++) begin
      @(vif.master_cb iff vif.master_cb.rvalid);
      req.data[i] = vif.master_cb.rdata;
      req.resp    = vif.master_cb.rresp;
    end
  endtask

endclass

`endif
