`ifndef DDR5_REFRESH_TEST_SV
`define DDR5_REFRESH_TEST_SV
class ddr5_refresh_test extends ddr5_base_test;
  `uvm_component_utils(ddr5_refresh_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    ddr5_refresh_seq rs;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== DDR5 Refresh Test: Normal/FGR/PBR/SBR ===",UVM_LOW)
    rs=ddr5_refresh_seq::type_id::create("ref_normal"); rs.ref_mode=REF_NORMAL; rs.num_ops=10;
    rs.start(env.agent.sequencer);
    rs=ddr5_refresh_seq::type_id::create("ref_fgr2x"); rs.ref_mode=REF_FGR_2X; rs.num_ops=20;
    rs.start(env.agent.sequencer);
    rs=ddr5_refresh_seq::type_id::create("ref_fgr4x"); rs.ref_mode=REF_FGR_4X; rs.num_ops=40;
    rs.start(env.agent.sequencer);
    rs=ddr5_refresh_seq::type_id::create("ref_pbr"); rs.ref_mode=REF_PBR; rs.num_ops=32;
    rs.start(env.agent.sequencer);
    rs=ddr5_refresh_seq::type_id::create("ref_sbr"); rs.ref_mode=REF_SBR; rs.num_ops=16;
    rs.start(env.agent.sequencer);
    #500ns; phase.drop_objection(this);
  endtask
endclass
`endif
