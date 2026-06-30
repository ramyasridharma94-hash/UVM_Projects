`ifndef PCIE_ATOMICOP_TEST_SV
`define PCIE_ATOMICOP_TEST_SV

// AtomicOp test — FetchAdd, Swap, CAS in 32b and 64b variants
class pcie_atomicop_test extends pcie_base_test;
  `uvm_component_utils(pcie_atomicop_test)
  import pcie_pkg::*;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_atomicop_seq atom_seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== AtomicOp Test ===", UVM_LOW)

    // 32-bit AtomicOps
    atom_seq = pcie_atomicop_seq::type_id::create("atom32");
    atom_seq.use_64bit = 0;
    atom_seq.start(env.agent.sequencer);

    // 64-bit AtomicOps
    atom_seq = pcie_atomicop_seq::type_id::create("atom64");
    atom_seq.use_64bit = 1;
    atom_seq.start(env.agent.sequencer);

    // Repeat with randomized addresses
    for (int i = 0; i < 4; i++) begin
      atom_seq = pcie_atomicop_seq::type_id::create($sformatf("atom_rand_%0d", i));
      if (!atom_seq.randomize())
        `uvm_fatal("RAND", "pcie_atomicop_test: randomize failed")
      atom_seq.start(env.agent.sequencer);
    end

    #200ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_atomicop_test

`endif
