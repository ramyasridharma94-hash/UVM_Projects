`ifndef DDR5_READ_TEST_SV
`define DDR5_READ_TEST_SV
class ddr5_read_test extends ddr5_base_test;
  `uvm_component_utils(ddr5_read_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    ddr5_write_seq ws; ddr5_read_seq rs;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== DDR5 Read/Write Test with CAS Latency ===",UVM_LOW)
    ws=ddr5_write_seq::type_id::create("pre_wr"); ws.num_ops=16; ws.start(env.agent.sequencer);
    rs=ddr5_read_seq::type_id::create("rd_bl8"); rs.use_ap=0; rs.bl=BL8; rs.num_ops=16;
    rs.start(env.agent.sequencer);
    rs=ddr5_read_seq::type_id::create("rd_bl16_ap"); rs.use_ap=1; rs.bl=BL16; rs.num_ops=8;
    rs.start(env.agent.sequencer);
    rs=ddr5_read_seq::type_id::create("rd_bc4"); rs.bl=BC4; rs.num_ops=8;
    rs.start(env.agent.sequencer);
    #500ns; phase.drop_objection(this);
  endtask
endclass
`endif
