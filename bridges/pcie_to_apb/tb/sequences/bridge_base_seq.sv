`ifndef APB_BRIDGE_BASE_SEQ_SV
`define APB_BRIDGE_BASE_SEQ_SV
class bridge_base_seq extends uvm_sequence #(pcie_tlp_seq_item);
  `uvm_object_utils(bridge_base_seq)
  import pcie_pkg::*;
  int unsigned num_pkts = 4;
  function new(string name = "bridge_base_seq"); super.new(name); endfunction
  task send(pcie_tlp_seq_item it);
    start_item(it);
    if (!it.randomize()) `uvm_fatal("RAND","bridge_base_seq: rand failed")
    finish_item(it);
  endtask
  task body(); endtask
endclass
`endif
