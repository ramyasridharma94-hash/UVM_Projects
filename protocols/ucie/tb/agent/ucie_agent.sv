`ifndef UCIE_AGENT_SV
`define UCIE_AGENT_SV

class ucie_agent extends uvm_agent;
  `uvm_component_utils(ucie_agent)

  ucie_sequencer seqr;
  ucie_driver    drv;
  ucie_monitor   mon;

  // Expose monitor ports at agent level for env connectivity
  uvm_analysis_port #(ucie_seq_item) tx_ap;
  uvm_analysis_port #(ucie_seq_item) rx_ap;

  function new(string name = "ucie_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_ap = new("tx_ap", this);
    rx_ap = new("rx_ap", this);
    mon   = ucie_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      seqr = ucie_sequencer::type_id::create("seqr", this);
      drv  = ucie_driver::type_id::create("drv",  this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(seqr.seq_item_export);
    mon.tx_ap.connect(tx_ap);
    mon.rx_ap.connect(rx_ap);
  endfunction

endclass

`endif
