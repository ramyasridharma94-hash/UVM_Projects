`ifndef I2C_READ_TEST_SV
`define I2C_READ_TEST_SV
class i2c_read_test extends i2c_base_test;
  `uvm_component_utils(i2c_read_test)
  function new(string name = "i2c_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    i2c_write_seq wr;
    i2c_read_seq  rd;
    phase.raise_objection(this);
    wr = i2c_write_seq::type_id::create("wr");
    wr.num_txns = 4;
    wr.start(env.agent.seqr);
    rd = i2c_read_seq::type_id::create("rd");
    rd.num_txns = 4;
    rd.start(env.agent.seqr);
    #500;
    phase.drop_objection(this);
  endtask
endclass
`endif
