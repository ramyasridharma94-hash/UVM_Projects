`ifndef UCIE_BURST_FLIT_TEST_SV
`define UCIE_BURST_FLIT_TEST_SV

// Sends 18 flits (2 boundary + 16 random) back-to-back to stress
// the 8-slot FIFO and credit-return flow control mechanism.
class ucie_burst_flit_test extends ucie_base_test;
  `uvm_component_utils(ucie_burst_flit_test)

  function new(string name = "ucie_burst_flit_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ucie_burst_flit_seq seq;
    phase.raise_objection(this);
    seq           = ucie_burst_flit_seq::type_id::create("seq");
    seq.num_flits = 16;
    seq.start(env.agent.seqr);
    #500; // Allow all 18 flits to drain through the 2-cycle pipeline
    phase.drop_objection(this);
  endtask

endclass

`endif
