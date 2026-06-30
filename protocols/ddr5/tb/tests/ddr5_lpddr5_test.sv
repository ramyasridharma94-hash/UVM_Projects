`ifndef DDR5_LPDDR5_TEST_SV
`define DDR5_LPDDR5_TEST_SV
class ddr5_lpddr5_test extends ddr5_base_test;
  `uvm_component_utils(ddr5_lpddr5_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    ddr5_lpddr5_seq ls;
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== LPDDR5: BL16, Dual-CH, DPD, PASR ===",UVM_LOW)
    // Single channel BL16
    ls=ddr5_lpddr5_seq::type_id::create("lp5_single"); ls.use_dpd=0; ls.use_pasr=0; ls.dual_ch=0;
    ls.num_ops=16; ls.start(env.agent.sequencer);
    // Dual channel
    ls=ddr5_lpddr5_seq::type_id::create("lp5_dual"); ls.dual_ch=1; ls.num_ops=16;
    ls.use_dpd=0; ls.use_pasr=0; ls.start(env.agent.sequencer);
    // DPD
    ls=ddr5_lpddr5_seq::type_id::create("lp5_dpd"); ls.use_dpd=1; ls.use_pasr=0; ls.dual_ch=0;
    ls.num_ops=4; ls.start(env.agent.sequencer);
    // PASR
    ls=ddr5_lpddr5_seq::type_id::create("lp5_pasr"); ls.use_dpd=0; ls.use_pasr=1; ls.dual_ch=0;
    ls.num_ops=4; ls.start(env.agent.sequencer);
    #500ns; phase.drop_objection(this);
  endtask
endclass
`endif
