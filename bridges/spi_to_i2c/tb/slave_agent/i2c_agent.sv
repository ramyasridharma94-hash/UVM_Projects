`ifndef I2C_BRIDGE_AGENT_SV
`define I2C_BRIDGE_AGENT_SV
class i2c_agent extends uvm_agent;
  `uvm_component_utils(i2c_agent)
  i2c_monitor mon;
  uvm_analysis_port #(i2c_seq_item) ap;
  function new(string name = "i2c_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    set_is_active(UVM_PASSIVE);
    mon = i2c_monitor::type_id::create("mon", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    mon.ap.connect(ap);
  endfunction
endclass
`endif
