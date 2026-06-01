`ifndef UCIE_SINGLE_FLIT_SEQ_SV
`define UCIE_SINGLE_FLIT_SEQ_SV

// Sends num_flits random 256-bit flits one at a time.
class ucie_single_flit_seq extends ucie_base_seq;
  `uvm_object_utils(ucie_single_flit_seq)

  int unsigned num_flits = 4;

  function new(string name = "ucie_single_flit_seq"); super.new(name); endfunction

  task body();
    ucie_seq_item req;
    repeat (num_flits) begin
      req = ucie_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize()) `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
      `uvm_info("SEQ", $sformatf("Sending flit: %s", req.convert2string()), UVM_MEDIUM)
    end
  endtask

endclass

`endif
