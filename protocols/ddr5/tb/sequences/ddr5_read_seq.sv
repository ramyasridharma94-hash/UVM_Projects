`ifndef DDR5_READ_SEQ_SV
`define DDR5_READ_SEQ_SV
class ddr5_read_seq extends ddr5_base_seq;
  `uvm_object_utils(ddr5_read_seq)
  import ddr5_pkg::*;
  rand bit use_ap;
  rand burst_len_e bl;

  function new(string name="ddr5_read_seq"); super.new(name); endfunction

  task body();
    for (int i = 0; i < num_ops; i++) begin
      // ACT
      ddr5_seq_item act = ddr5_seq_item::type_id::create($sformatf("act_%0d",i));
      start_item(act);
      if (!act.randomize() with { cmd==CMD_ACT; }) `uvm_fatal("RAND","read_seq ACT")
      finish_item(act);
      // RD
      ddr5_seq_item it = ddr5_seq_item::type_id::create($sformatf("rd_%0d",i));
      start_item(it);
      if (!it.randomize() with {
          cmd == (use_ap ? CMD_RDA : CMD_RD);
          auto_precharge == use_ap; burst_len == bl;
          it.bg == act.bg; it.bank == act.bank;
      })
        `uvm_fatal("RAND","read_seq RD")
      finish_item(it);
      if (!use_ap) begin
        ddr5_seq_item pre = ddr5_seq_item::type_id::create($sformatf("pre_%0d",i));
        start_item(pre);
        if (!pre.randomize() with { cmd==CMD_PRE; pre.bg==it.bg; pre.bank==it.bank; })
          `uvm_fatal("RAND","read_seq PRE")
        finish_item(pre);
      end
    end
  endtask
endclass
`endif
