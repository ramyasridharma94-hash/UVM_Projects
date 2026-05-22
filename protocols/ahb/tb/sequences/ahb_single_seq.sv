`ifndef AHB_SINGLE_SEQ_SV
`define AHB_SINGLE_SEQ_SV
class ahb_single_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_single_seq)
  int unsigned num_txns = 8;
  function new(string name = "ahb_single_seq"); super.new(name); endfunction
  task body();
    ahb_seq_item req;
    repeat (num_txns) begin
      req = ahb_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { burst == 3'b000; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass
`endif
