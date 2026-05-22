`ifndef AHB_MST_SEQUENCER_SV
`define AHB_MST_SEQUENCER_SV
class ahb_sequencer extends uvm_sequencer #(ahb_seq_item);
  `uvm_component_utils(ahb_sequencer)
  function new(string name = "ahb_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
`endif
