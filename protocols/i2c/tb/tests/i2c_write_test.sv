`ifndef I2C_WRITE_TEST_SV
`define I2C_WRITE_TEST_SV
class i2c_write_test extends i2c_base_test;
  `uvm_component_utils(i2c_write_test)
  function new(string name = "i2c_write_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    i2c_write_seq seq;
    phase.raise_objection(this);
    seq = i2c_write_seq::type_id::create("seq");
    seq.num_txns = 4;
    seq.start(env.agent.seqr);
    #500;
    phase.drop_objection(this);
  endtask
endclass
`endif
