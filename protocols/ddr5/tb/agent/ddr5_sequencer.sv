`ifndef DDR5_SEQUENCER_SV
`define DDR5_SEQUENCER_SV
class ddr5_sequencer extends uvm_sequencer #(ddr5_seq_item);
  `uvm_component_utils(ddr5_sequencer)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
`endif
