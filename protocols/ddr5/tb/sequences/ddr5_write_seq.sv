`ifndef DDR5_WRITE_SEQ_SV
`define DDR5_WRITE_SEQ_SV
class ddr5_write_seq extends ddr5_base_seq;
  `uvm_object_utils(ddr5_write_seq)
  import ddr5_pkg::*;
  rand bit use_ap;         // Auto-Precharge
  rand bit use_wmask;
  rand burst_len_e bl;

  function new(string name="ddr5_write_seq"); super.new(name); endfunction

  task body();
    for (int i = 0; i < num_ops; i++) begin
      ddr5_seq_item it = ddr5_seq_item::type_id::create($sformatf("wr_%0d",i));
      // ACT first
      ddr5_seq_item act = ddr5_seq_item::type_id::create($sformatf("act_%0d",i));
      start_item(act);
      if (!act.randomize() with { cmd==CMD_ACT; }) `uvm_fatal("RAND","write_seq ACT")
      finish_item(act);
      // WR
      start_item(it);
      if (!it.randomize() with {
          cmd == (use_ap ? CMD_WRA : CMD_WR);
          auto_precharge == use_ap;
          burst_len == bl;
          (use_wmask) -> wmask inside {[32'h1:32'hFF]};
          (!use_wmask) -> wmask == 32'h0;
          it.bg == act.bg; it.bank == act.bank;
      })
        `uvm_fatal("RAND","write_seq WR")
      finish_item(it);
      // PRE if not AP
      if (!use_ap) begin
        ddr5_seq_item pre = ddr5_seq_item::type_id::create($sformatf("pre_%0d",i));
        start_item(pre);
        if (!pre.randomize() with { cmd==CMD_PRE; pre.bg==act.bg; pre.bank==act.bank; })
          `uvm_fatal("RAND","write_seq PRE")
        finish_item(pre);
      end
      `uvm_info("WR_SEQ",$sformatf("[%0d] %s", i, it.convert2string()), UVM_HIGH)
    end
  endtask
endclass
`endif
