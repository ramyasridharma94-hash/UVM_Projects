`ifndef AXI_LITE_AGENT_SV
`define AXI_LITE_AGENT_SV
class axi_lite_agent extends uvm_agent;
  `uvm_component_utils(axi_lite_agent)
  axi_lite_sequencer seqr;
  axi_lite_driver    drv;
  axi_lite_monitor   mon;
  uvm_analysis_port #(axi_lite_seq_item) ap;
  function new(string name = "axi_lite_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    mon = axi_lite_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      seqr = axi_lite_sequencer::type_id::create("seqr", this);
      drv  = axi_lite_driver::type_id::create("drv",  this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE) drv.seq_item_port.connect(seqr.seq_item_export);
    mon.ap.connect(ap);
  endfunction
endclass
`endif
