`ifndef DDR5_WRITE_TEST_SV
`define DDR5_WRITE_TEST_SV
class ddr5_write_test extends ddr5_base_test;
  `uvm_component_utils(ddr5_write_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    ddr5_write_seq ws;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== DDR5 Write Test: BL8/BL16, AP, wmask ===",UVM_LOW)
    // BL8 no-AP
    ws=ddr5_write_seq::type_id::create("bl8_noap"); ws.use_ap=0; ws.use_wmask=0;
    ws.bl=BL8; ws.num_ops=16; ws.start(env.agent.sequencer);
    // BL16 with AP
    ws=ddr5_write_seq::type_id::create("bl16_ap"); ws.use_ap=1; ws.use_wmask=0;
    ws.bl=BL16; ws.num_ops=16; ws.start(env.agent.sequencer);
    // With write mask
    ws=ddr5_write_seq::type_id::create("wmask"); ws.use_ap=0; ws.use_wmask=1;
    ws.bl=BL8; ws.num_ops=8; ws.start(env.agent.sequencer);
    #500ns; phase.drop_objection(this);
  endtask
endclass
`endif
