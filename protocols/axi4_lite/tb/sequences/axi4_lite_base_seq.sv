`ifndef AXI4_LITE_BASE_SEQ_SV
`define AXI4_LITE_BASE_SEQ_SV
class axi4_lite_base_seq extends uvm_sequence #(axi4_lite_seq_item);
  `uvm_object_utils(axi4_lite_base_seq)
  function new(string name = "axi4_lite_base_seq"); super.new(name); endfunction
  task body(); endtask
endclass
`endif
