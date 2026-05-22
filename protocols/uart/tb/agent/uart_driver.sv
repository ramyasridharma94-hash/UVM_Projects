`ifndef UART_DRIVER_SV
`define UART_DRIVER_SV

class uart_driver extends uvm_driver #(uart_seq_item);
  `uvm_component_utils(uart_driver)

  virtual uart_if.master_mp vif;

  function new(string name = "uart_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual uart_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "UART driver: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    uart_seq_item req;
    vif.master_cb.tx_data  <= 8'h00;
    vif.master_cb.tx_valid <= 1'b0;
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      send_byte(req);
      seq_item_port.item_done();
    end
  endtask

  task send_byte(uart_seq_item req);
    // Wait until DUT is ready to accept
    @(vif.master_cb iff vif.master_cb.tx_ready);
    vif.master_cb.tx_data  <= req.data;
    vif.master_cb.tx_valid <= 1'b1;
    @(vif.master_cb);
    vif.master_cb.tx_valid <= 1'b0;
    // Wait for transmission to complete (tx_ready goes low then high)
    @(vif.master_cb iff !vif.master_cb.tx_ready);
    @(vif.master_cb iff  vif.master_cb.tx_ready);
    `uvm_info("UART_DRV", $sformatf("Sent: %s", req.convert2string()), UVM_HIGH)
  endtask

endclass

`endif
