`ifndef I2C_AGENT_SV
`define I2C_AGENT_SV
class i2c_agent extends uvm_agent;
  `uvm_component_utils(i2c_agent)
  i2c_sequencer seqr;
  i2c_driver    drv;
  i2c_monitor   mon;
  uvm_analysis_port #(i2c_seq_item) ap;
  function new(string name = "i2c_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    mon = i2c_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      seqr = i2c_sequencer::type_id::create("seqr", this);
      drv  = i2c_driver::type_id::create("drv",  this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(seqr.seq_item_export);
    mon.ap.connect(ap);
  endfunction
endclass
`endif
