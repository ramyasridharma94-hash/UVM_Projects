`ifndef BRIDGE_AHB_APB_WRITE_SEQ_SV
`define BRIDGE_AHB_APB_WRITE_SEQ_SV
class bridge_write_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_write_seq)
  int unsigned num_txns = 8;
  function new(string name = "bridge_write_seq"); super.new(name); endfunction
  task body();
    ahb_seq_item req;
    repeat (num_txns) begin
      req = ahb_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { op == AHB_MST_WRITE; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass
`endif
