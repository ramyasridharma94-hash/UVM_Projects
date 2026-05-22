`ifndef I2C_DRIVER_SV
`define I2C_DRIVER_SV

// I2C master driver — generates SCL/SDA waveforms via interface signals
class i2c_driver extends uvm_driver #(i2c_seq_item);
  `uvm_component_utils(i2c_driver)

  virtual i2c_if.master_mp vif;
  int SCL_HALF = 10; // half-period in time units

  function new(string name = "i2c_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual i2c_if.master_mp)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "I2C driver: no vif")
  endfunction

  task run_phase(uvm_phase phase);
    i2c_seq_item req;
    idle_bus();
    @(posedge vif.master_cb.clk iff vif.rst_n);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.op == I2C_WRITE) do_write(req);
      else                      do_read(req);
      seq_item_port.item_done();
    end
  endtask

  task idle_bus();
    vif.master_cb.scl_drv <= 1;
    vif.master_cb.sda_drv <= 1;
    vif.master_cb.sda_oe  <= 1;
  endtask

  task start_condition();
    vif.master_cb.sda_drv <= 1; #(SCL_HALF);
    vif.master_cb.scl_drv <= 1; #(SCL_HALF);
    vif.master_cb.sda_drv <= 0; #(SCL_HALF); // SDA falls while SCL high
    vif.master_cb.scl_drv <= 0; #(SCL_HALF);
  endtask

  task stop_condition();
    vif.master_cb.sda_drv <= 0; #(SCL_HALF);
    vif.master_cb.scl_drv <= 1; #(SCL_HALF);
    vif.master_cb.sda_drv <= 1; #(SCL_HALF); // SDA rises while SCL high
  endtask

  task send_bit(input bit b);
    vif.master_cb.sda_drv <= b;
    vif.master_cb.sda_oe  <= 1;
    #(SCL_HALF);
    vif.master_cb.scl_drv <= 1; #(SCL_HALF);
    vif.master_cb.scl_drv <= 0; #(SCL_HALF);
  endtask

  task recv_bit(output bit b);
    vif.master_cb.sda_oe <= 0;
    #(SCL_HALF);
    vif.master_cb.scl_drv <= 1; #(SCL_HALF);
    b = vif.master_cb.sda;
    vif.master_cb.scl_drv <= 0; #(SCL_HALF);
  endtask

  task send_byte(input bit [7:0] data, output bit ack);
    for (int i = 7; i >= 0; i--) send_bit(data[i]);
    recv_bit(ack); // ACK from slave
  endtask

  task recv_byte(output bit [7:0] data, input bit send_nack);
    bit b;
    for (int i = 7; i >= 0; i--) begin recv_bit(b); data[i] = b; end
    send_bit(send_nack); // NACK to end, ACK to continue
  endtask

  task do_write(i2c_seq_item req);
    bit ack;
    start_condition();
    send_byte({req.slave_addr, 1'b0}, ack); // W
    send_byte(req.reg_addr, ack);
    foreach (req.data[i]) send_byte(req.data[i], ack);
    stop_condition();
    req.nack = ack;
  endtask

  task do_read(i2c_seq_item req);
    bit ack;
    // Write phase: send slave addr + reg addr
    start_condition();
    send_byte({req.slave_addr, 1'b0}, ack);
    send_byte(req.reg_addr, ack);
    // Repeated START
    start_condition();
    send_byte({req.slave_addr, 1'b1}, ack); // R
    foreach (req.data[i])
      recv_byte(req.data[i], (i == req.data.size()-1)); // NACK on last
    stop_condition();
  endtask

endclass

`endif
