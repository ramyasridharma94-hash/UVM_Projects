`ifndef AHB_MST_DRIVER_SV
`define AHB_MST_DRIVER_SV
class ahb_driver extends uvm_driver #(ahb_seq_item);
  `uvm_component_utils(ahb_driver)
  virtual ahb_if.master_mp vif;
  function new(string name = "ahb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ahb_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "AHB master driver (bridge): no vif")
  endfunction
  task run_phase(uvm_phase phase);
    ahb_seq_item req;
    vif.master_cb.htrans <= 2'b00; vif.master_cb.hsel <= 0;
    vif.master_cb.hwrite <= 0;     vif.master_cb.hsize  <= 3'b010;
    vif.master_cb.hburst <= 3'b000;
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      // Address phase
      @(vif.master_cb);
      vif.master_cb.haddr  <= req.addr;
      vif.master_cb.htrans <= 2'b10; // NONSEQ
      vif.master_cb.hwrite <= (req.op == AHB_MST_WRITE);
      vif.master_cb.hsize  <= 3'b010;
      vif.master_cb.hburst <= 3'b000;
      vif.master_cb.hsel   <= 1;
      // Wait for HREADY_OUT from bridge
      @(vif.master_cb iff vif.master_cb.hready_out);
      // Data phase
      if (req.op == AHB_MST_WRITE) vif.master_cb.hwdata <= req.data;
      @(vif.master_cb iff vif.master_cb.hready_out);
      req.hresp = vif.master_cb.hresp;
      if (req.op == AHB_MST_READ)  req.data = vif.master_cb.hrdata;
      // IDLE
      @(vif.master_cb);
      vif.master_cb.htrans <= 2'b00;
      vif.master_cb.hsel   <= 0;
      seq_item_port.item_done();
    end
  endtask
endclass
`endif
