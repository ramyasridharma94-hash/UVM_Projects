`ifndef AHB_AGENT_SV
`define AHB_AGENT_SV
class ahb_agent extends uvm_agent;
  `uvm_component_utils(ahb_agent)
  ahb_sequencer seqr;
  ahb_driver    drv;
  ahb_monitor   mon;
  uvm_analysis_port #(ahb_seq_item) ap;
  function new(string name = "ahb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    mon = ahb_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      seqr = ahb_sequencer::type_id::create("seqr", this);
      drv  = ahb_driver::type_id::create("drv",  this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(seqr.seq_item_export);
    mon.ap.connect(ap);
  endfunction
endclass
`endif
