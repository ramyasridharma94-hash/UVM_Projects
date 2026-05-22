`ifndef AXI4_WRITE_SEQ_SV
`define AXI4_WRITE_SEQ_SV

class axi4_write_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_write_seq)

  int unsigned num_txns = 8;

  function new(string name = "axi4_write_seq");
    super.new(name);
  endfunction

  task body();
    axi4_seq_item req;
    repeat (num_txns) begin
      req = axi4_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with {
        op    == AXI4_WRITE;
        len   == 0;           // single beat
        burst == 1;           // INCR
      }) `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
      `uvm_info("SEQ", $sformatf("Write txn: %s", req.convert2string()), UVM_MEDIUM)
    end
  endtask

endclass

`endif
