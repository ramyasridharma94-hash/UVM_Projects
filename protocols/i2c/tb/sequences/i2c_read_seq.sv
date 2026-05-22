`ifndef I2C_READ_SEQ_SV
`define I2C_READ_SEQ_SV
class i2c_read_seq extends i2c_base_seq;
  `uvm_object_utils(i2c_read_seq)
  int unsigned num_txns = 4;
  function new(string name = "i2c_read_seq"); super.new(name); endfunction
  task body();
    i2c_seq_item req;
    repeat (num_txns) begin
      req = i2c_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { op == I2C_READ; data.size() == 1; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass
`endif
