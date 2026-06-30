`ifndef PCIE_BASE_SEQ_SV
`define PCIE_BASE_SEQ_SV

class pcie_base_seq extends uvm_sequence #(pcie_tlp_seq_item);
  `uvm_object_utils(pcie_base_seq)
  import pcie_pkg::*;

  int unsigned num_pkts = 1;

  function new(string name = "pcie_base_seq");
    super.new(name);
  endfunction

  // Convenience: create & randomize, then apply overrides before starting
  task send_tlp(pcie_tlp_seq_item item);
    start_item(item);
    if (!item.randomize())
      `uvm_fatal("RAND", "pcie_base_seq: randomization failed")
    finish_item(item);
  endtask

  task body();
    `uvm_info(get_type_name(), "Base sequence — override body() in derived class", UVM_LOW)
  endtask

endclass : pcie_base_seq

`endif
