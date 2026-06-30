`ifndef AXI4_PCIE_TLP_SEQUENCER_SV
`define AXI4_PCIE_TLP_SEQUENCER_SV
class pcie_tlp_sequencer extends uvm_sequencer #(pcie_tlp_seq_item);
  `uvm_component_utils(pcie_tlp_sequencer)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
`endif
