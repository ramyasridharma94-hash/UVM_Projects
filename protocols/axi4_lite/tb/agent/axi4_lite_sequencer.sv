`ifndef AXI4_LITE_SEQUENCER_SV
`define AXI4_LITE_SEQUENCER_SV

class axi4_lite_sequencer extends uvm_sequencer #(axi4_lite_seq_item);
  `uvm_component_utils(axi4_lite_sequencer)
  function new(string name = "axi4_lite_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

`endif
