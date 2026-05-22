`ifndef AHB_BASE_SEQ_SV
`define AHB_BASE_SEQ_SV
class ahb_base_seq extends uvm_sequence #(ahb_seq_item);
  `uvm_object_utils(ahb_base_seq)
  function new(string name = "ahb_base_seq"); super.new(name); endfunction
  task body(); endtask
endclass
`endif
