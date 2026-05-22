`ifndef AXI4_BURST_SEQ_SV
`define AXI4_BURST_SEQ_SV

class axi4_burst_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_burst_seq)

  int unsigned num_txns = 4;

  function new(string name = "axi4_burst_seq");
    super.new(name);
  endfunction

  task body();
    axi4_seq_item req;
    // Burst write then read back
    repeat (num_txns) begin
      req = axi4_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with {
        op    == AXI4_WRITE;
        len   inside {[3:7]};
        burst == 1;
      }) `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);

      // Read back same address
      begin
        axi4_seq_item rd = axi4_seq_item::type_id::create("rd");
        start_item(rd);
        if (!rd.randomize() with {
          op    == AXI4_READ;
          addr  == req.addr;
          len   == req.len;
          burst == 1;
        }) `uvm_fatal("SEQ", "Randomization failed")
        finish_item(rd);
      end
    end
  endtask

endclass

`endif
