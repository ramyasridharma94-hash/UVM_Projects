`ifndef AHB_DRIVER_SV
`define AHB_DRIVER_SV

class ahb_driver extends uvm_driver #(ahb_seq_item);
  `uvm_component_utils(ahb_driver)

  virtual ahb_if.master_mp vif;

  function new(string name = "ahb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ahb_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "AHB driver: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    ahb_seq_item req;
    reset_signals();
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      drive_transfer(req);
      seq_item_port.item_done();
    end
  endtask

  task reset_signals();
    vif.master_cb.haddr  <= 0;
    vif.master_cb.htrans <= 2'b00; // IDLE
    vif.master_cb.hwrite <= 0;
    vif.master_cb.hsize  <= 3'b010;
    vif.master_cb.hburst <= 3'b000;
    vif.master_cb.hwdata <= 0;
    vif.master_cb.hsel   <= 0;
  endtask

  task drive_transfer(ahb_seq_item req);
    foreach (req.data[i]) begin
      // Address phase
      @(vif.master_cb);
      vif.master_cb.haddr  <= req.addr + (i * 4);
      vif.master_cb.htrans <= (i == 0) ? 2'b10 : 2'b11; // NONSEQ or SEQ
      vif.master_cb.hwrite <= (req.op == AHB_WRITE);
      vif.master_cb.hsize  <= req.size;
      vif.master_cb.hburst <= req.burst;
      vif.master_cb.hsel   <= 1;

      // Wait for HREADY (slave may insert wait states)
      @(vif.master_cb iff vif.master_cb.hready);

      // Data phase
      if (req.op == AHB_WRITE)
        vif.master_cb.hwdata <= req.data[i];
      else
        req.data[i] = vif.master_cb.hrdata;
    end

    // IDLE after burst
    @(vif.master_cb);
    vif.master_cb.htrans <= 2'b00;
    vif.master_cb.hsel   <= 0;
    req.hresp = vif.master_cb.hresp;
  endtask

endclass

`endif
