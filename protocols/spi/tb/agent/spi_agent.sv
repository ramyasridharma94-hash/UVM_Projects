`ifndef SPI_AGENT_SV
`define SPI_AGENT_SV
class spi_agent extends uvm_agent;
  `uvm_component_utils(spi_agent)
  spi_sequencer seqr;
  spi_driver    drv;
  spi_monitor   mon;
  uvm_analysis_port #(spi_seq_item) ap;
  function new(string name = "spi_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    mon = spi_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      seqr = spi_sequencer::type_id::create("seqr", this);
      drv  = spi_driver::type_id::create("drv",  this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(seqr.seq_item_export);
    mon.ap.connect(ap);
  endfunction
endclass
`endif
