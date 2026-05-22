`ifndef BRIDGE_AHB_APB_BASE_SEQ_SV
`define BRIDGE_AHB_APB_BASE_SEQ_SV
class bridge_base_seq extends uvm_sequence #(ahb_seq_item);
  `uvm_object_utils(bridge_base_seq)
  function new(string name = "bridge_base_seq"); super.new(name); endfunction
  task body(); endtask
endclass
`endif
