`ifndef BRIDGE_SPI_I2C_WRITE_TEST_SV
`define BRIDGE_SPI_I2C_WRITE_TEST_SV
class bridge_write_test extends bridge_base_test;
  `uvm_component_utils(bridge_write_test)
  function new(string name = "bridge_write_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    bridge_write_seq seq;
    phase.raise_objection(this);
    seq = bridge_write_seq::type_id::create("seq");
    seq.num_txns = 4;
    seq.start(env.master_agent.seqr);
    #2000;
    phase.drop_objection(this);
  endtask
endclass
`endif
