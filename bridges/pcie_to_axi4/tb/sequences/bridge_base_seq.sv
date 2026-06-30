`ifndef AXI4_BRIDGE_BASE_SEQ_SV
`define AXI4_BRIDGE_BASE_SEQ_SV
class bridge_base_seq extends uvm_sequence #(pcie_tlp_seq_item);
  `uvm_object_utils(bridge_base_seq)
  import pcie_pkg::*;
  int unsigned num_pkts = 4;
  function new(string name="bridge_base_seq"); super.new(name); endfunction
  task body(); endtask
endclass
`endif
