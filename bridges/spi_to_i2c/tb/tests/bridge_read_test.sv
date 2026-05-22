`ifndef BRIDGE_SPI_I2C_READ_TEST_SV
`define BRIDGE_SPI_I2C_READ_TEST_SV
class bridge_read_test extends bridge_base_test;
  `uvm_component_utils(bridge_read_test)
  function new(string name = "bridge_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    bridge_write_seq wr;
    bridge_read_seq  rd;
    phase.raise_objection(this);
    wr = bridge_write_seq::type_id::create("wr"); wr.num_txns = 2; wr.start(env.master_agent.seqr);
    rd = bridge_read_seq::type_id::create("rd");  rd.num_txns = 2; rd.start(env.master_agent.seqr);
    #2000;
    phase.drop_objection(this);
  endtask
endclass
`endif
