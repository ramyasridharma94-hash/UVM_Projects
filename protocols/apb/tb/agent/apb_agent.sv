`ifndef APB_AGENT_SV
`define APB_AGENT_SV
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)
  apb_sequencer seqr;
  apb_driver    drv;
  apb_monitor   mon;
  uvm_analysis_port #(apb_seq_item) ap;
  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    mon = apb_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      seqr = apb_sequencer::type_id::create("seqr", this);
      drv  = apb_driver::type_id::create("drv",  this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(seqr.seq_item_export);
    mon.ap.connect(ap);
  endfunction
endclass
`endif
