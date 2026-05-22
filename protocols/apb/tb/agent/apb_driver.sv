`ifndef APB_DRIVER_SV
`define APB_DRIVER_SV

class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if.master_mp vif;

  function new(string name = "apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "APB driver: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item req;
    reset_signals();
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      drive_txn(req);
      seq_item_port.item_done();
    end
  endtask

  task reset_signals();
    vif.master_cb.paddr   <= 0;
    vif.master_cb.psel    <= 0;
    vif.master_cb.penable <= 0;
    vif.master_cb.pwrite  <= 0;
    vif.master_cb.pwdata  <= 0;
  endtask

  task drive_txn(apb_seq_item req);
    // SETUP phase
    @(vif.master_cb);
    vif.master_cb.paddr   <= req.addr;
    vif.master_cb.pwrite  <= (req.op == APB_WRITE);
    vif.master_cb.pwdata  <= (req.op == APB_WRITE) ? req.data : 32'h0;
    vif.master_cb.psel    <= 1;
    vif.master_cb.penable <= 0;

    // ENABLE phase
    @(vif.master_cb);
    vif.master_cb.penable <= 1;

    // Wait for PREADY
    @(vif.master_cb iff vif.master_cb.pready);
    req.pslverr = vif.master_cb.pslverr;
    if (req.op == APB_READ)
      req.data = vif.master_cb.prdata;

    // Deassert
    @(vif.master_cb);
    vif.master_cb.psel    <= 0;
    vif.master_cb.penable <= 0;
  endtask

endclass

`endif
