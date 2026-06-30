`ifndef PCIE_AGENT_SV
`define PCIE_AGENT_SV

class pcie_agent extends uvm_agent;
  `uvm_component_utils(pcie_agent)

  pcie_sequencer  sequencer;
  pcie_driver     driver;
  pcie_monitor    monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = pcie_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = pcie_sequencer::type_id::create("sequencer", this);
      driver    = pcie_driver::type_id::create("driver",    this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass : pcie_agent

`endif
