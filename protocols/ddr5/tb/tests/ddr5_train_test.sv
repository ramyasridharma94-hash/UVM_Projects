`ifndef DDR5_TRAIN_TEST_SV
`define DDR5_TRAIN_TEST_SV
class ddr5_train_test extends ddr5_base_test;
  `uvm_component_utils(ddr5_train_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    ddr5_train_seq ts;
    ddr5_write_seq ws; ddr5_read_seq rs;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== DDR5 PHY Training Test (ZQ/CA/WL/DQS/VREF) ===",UVM_LOW)
    ts=ddr5_train_seq::type_id::create("train"); ts.start(env.agent.sequencer);
    // Post-training traffic
    ws=ddr5_write_seq::type_id::create("post_train_wr"); ws.num_ops=8;
    ws.start(env.agent.sequencer);
    rs=ddr5_read_seq::type_id::create("post_train_rd"); rs.num_ops=8;
    rs.start(env.agent.sequencer);
    #500ns; phase.drop_objection(this);
  endtask
endclass
`endif
