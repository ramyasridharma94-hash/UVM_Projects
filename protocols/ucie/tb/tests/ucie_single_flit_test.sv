`ifndef UCIE_SINGLE_FLIT_TEST_SV
`define UCIE_SINGLE_FLIT_TEST_SV

// Sends 4 random 256-bit flits, one at a time, and verifies loopback integrity.
class ucie_single_flit_test extends ucie_base_test;
  `uvm_component_utils(ucie_single_flit_test)

  function new(string name = "ucie_single_flit_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ucie_single_flit_seq seq;
    phase.raise_objection(this);
    seq           = ucie_single_flit_seq::type_id::create("seq");
    seq.num_flits = 4;
    seq.start(env.agent.seqr);
    #200; // Allow 2-cycle TX→RX pipeline latency to flush
    phase.drop_objection(this);
  endtask

endclass

`endif
