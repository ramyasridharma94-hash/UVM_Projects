`ifndef APB_READ_SEQ_SV
`define APB_READ_SEQ_SV
class apb_read_seq extends apb_base_seq;
  `uvm_object_utils(apb_read_seq)
  int unsigned num_txns = 8;
  function new(string name = "apb_read_seq"); super.new(name); endfunction
  task body();
    apb_seq_item req;
    repeat (num_txns) begin
      req = apb_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { op == APB_READ; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass
`endif
