`ifndef BRIDGE_READ_SEQ_SV
`define BRIDGE_READ_SEQ_SV
class bridge_read_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_read_seq)
  int unsigned num_txns = 8;
  function new(string name = "bridge_read_seq"); super.new(name); endfunction
  task body();
    axi_lite_seq_item req;
    repeat (num_txns) begin
      req = axi_lite_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { op == AXIL_READ; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass
`endif
