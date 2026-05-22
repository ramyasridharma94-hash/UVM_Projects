`ifndef AHB_BURST_SEQ_SV
`define AHB_BURST_SEQ_SV
class ahb_burst_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_burst_seq)
  int unsigned num_txns = 4;
  function new(string name = "ahb_burst_seq"); super.new(name); endfunction
  task body();
    ahb_seq_item req;
    repeat (num_txns) begin
      req = ahb_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { burst == 3'b011; op == AHB_WRITE; }) // INCR4 write
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
      // Read back
      begin
        ahb_seq_item rd = ahb_seq_item::type_id::create("rd");
        start_item(rd);
        if (!rd.randomize() with { burst == 3'b011; op == AHB_READ; addr == req.addr; })
          `uvm_fatal("SEQ", "Randomization failed")
        finish_item(rd);
      end
    end
  endtask
endclass
`endif
