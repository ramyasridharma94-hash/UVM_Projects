`ifndef UCIE_BASE_SEQ_SV
`define UCIE_BASE_SEQ_SV

class ucie_base_seq extends uvm_sequence #(ucie_seq_item);
  `uvm_object_utils(ucie_base_seq)
  function new(string name = "ucie_base_seq"); super.new(name); endfunction
  task body(); endtask
endclass

`endif
