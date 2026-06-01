`ifndef UCIE_BURST_FLIT_SEQ_SV
`define UCIE_BURST_FLIT_SEQ_SV

// Sends a large burst of flits to exercise the credit-based flow control and FIFO.
// Starts with boundary patterns (all-0, all-1) then random data to stress integrity.
class ucie_burst_flit_seq extends ucie_base_seq;
  `uvm_object_utils(ucie_burst_flit_seq)

  int unsigned num_flits = 16;

  function new(string name = "ucie_burst_flit_seq"); super.new(name); endfunction

  task body();
    ucie_seq_item req;

    // Boundary: all-zeros flit
    req = ucie_seq_item::type_id::create("req");
    start_item(req);
    req.flit_data = '0;
    finish_item(req);

    // Boundary: all-ones flit
    req = ucie_seq_item::type_id::create("req");
    start_item(req);
    req.flit_data = '1;
    finish_item(req);

    // Random flits to exercise credit replenishment under sustained load
    repeat (num_flits) begin
      req = ucie_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize()) `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
      `uvm_info("SEQ", $sformatf("Burst flit: %s", req.convert2string()), UVM_MEDIUM)
    end
  endtask

endclass

`endif
