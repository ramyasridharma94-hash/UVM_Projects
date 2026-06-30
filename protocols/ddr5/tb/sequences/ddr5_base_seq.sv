`ifndef DDR5_BASE_SEQ_SV
`define DDR5_BASE_SEQ_SV
class ddr5_base_seq extends uvm_sequence #(ddr5_seq_item);
  `uvm_object_utils(ddr5_base_seq)
  import ddr5_pkg::*;
  int unsigned num_ops = 4;

  function new(string name = "ddr5_base_seq"); super.new(name); endfunction

  // Helper: issue ACT → (WR|RD) → PRE for a single bank
  task activate_rw_precharge(ddr5_cmd_e rw_cmd,
                              logic [2:0] bg, logic [1:0] bank,
                              logic [16:0] row, logic [9:0] col,
                              logic [255:0] wdata = 0);
    ddr5_seq_item act, rw, pre;
    // ACT
    act = ddr5_seq_item::type_id::create("act");
    start_item(act);
    if (!act.randomize() with { cmd==CMD_ACT; act.bg==bg; act.bank==bank; act.row==row; })
      `uvm_fatal("RAND","ddr5_base_seq: ACT rand failed")
    finish_item(act);
    // RD/WR
    rw = ddr5_seq_item::type_id::create("rw");
    start_item(rw);
    if (!rw.randomize() with { cmd==rw_cmd; rw.bg==bg; rw.bank==bank; rw.col==col;
                               rw.wdata==wdata; auto_precharge==0; })
      `uvm_fatal("RAND","ddr5_base_seq: RW rand failed")
    finish_item(rw);
    // PRE
    pre = ddr5_seq_item::type_id::create("pre");
    start_item(pre);
    if (!pre.randomize() with { cmd==CMD_PRE; pre.bg==bg; pre.bank==bank; })
      `uvm_fatal("RAND","ddr5_base_seq: PRE rand failed")
    finish_item(pre);
  endtask

  task body(); endtask
endclass
`endif
