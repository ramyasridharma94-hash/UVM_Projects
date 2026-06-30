`ifndef AHB_PCIE_TLP_AGENT_SV
`define AHB_PCIE_TLP_AGENT_SV
class pcie_tlp_agent extends uvm_agent;
  `uvm_component_utils(pcie_tlp_agent)
  pcie_tlp_sequencer sequencer; pcie_tlp_driver driver; pcie_tlp_monitor monitor;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = pcie_tlp_monitor::type_id::create("monitor",this);
    if (get_is_active()==UVM_ACTIVE) begin
      sequencer = pcie_tlp_sequencer::type_id::create("sequencer",this);
      driver    = pcie_tlp_driver::type_id::create("driver",this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (get_is_active()==UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
`endif
