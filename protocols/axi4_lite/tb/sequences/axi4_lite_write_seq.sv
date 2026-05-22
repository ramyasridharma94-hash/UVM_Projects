`ifndef AXI4_LITE_WRITE_SEQ_SV
`define AXI4_LITE_WRITE_SEQ_SV
class axi4_lite_write_seq extends axi4_lite_base_seq;
  `uvm_object_utils(axi4_lite_write_seq)
  int unsigned num_txns = 8;
  function new(string name = "axi4_lite_write_seq"); super.new(name); endfunction
  task body();
    axi4_lite_seq_item req;
    repeat (num_txns) begin
      req = axi4_lite_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { op == AXI4L_WRITE; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass
`endif
