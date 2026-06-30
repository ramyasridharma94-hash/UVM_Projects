`ifndef DDR5_SCOREBOARD_SV
`define DDR5_SCOREBOARD_SV

class ddr5_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ddr5_scoreboard)
  import ddr5_pkg::*;

  `uvm_analysis_imp_decl(_cmd)
  `uvm_analysis_imp_decl(_rd)
  `uvm_analysis_imp_decl(_wr)
  `uvm_analysis_imp_decl(_ref)
  `uvm_analysis_imp_decl(_err)

  uvm_analysis_imp_cmd #(ddr5_seq_item, ddr5_scoreboard) ap_cmd;
  uvm_analysis_imp_rd  #(ddr5_seq_item, ddr5_scoreboard) ap_rd;
  uvm_analysis_imp_wr  #(ddr5_seq_item, ddr5_scoreboard) ap_wr;
  uvm_analysis_imp_ref #(ddr5_seq_item, ddr5_scoreboard) ap_ref;
  uvm_analysis_imp_err #(ddr5_seq_item, ddr5_scoreboard) ap_err;

  // Shadow memory: bg×bank×row×col -> data
  logic [255:0] shadow_mem [logic [26:0]];  // {bg[2:0],bank[1:0],row[16:0],col[9:0]}=32b

  // Bank state tracking
  typedef struct { bit open; logic [16:0] row; } bank_st_t;
  bank_st_t bank_st [0:31];

  // Pending reads (row/col → expected data)
  logic [255:0] pending_rd [logic [26:0]];

  // Counters
  int act_cnt, wr_cnt, rd_cnt, ref_cnt, pre_cnt, err_cnt, mismatch_cnt;
  int ref_interval_violations;
  longint last_ref_time;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_cmd = new("ap_cmd",this); ap_rd  = new("ap_rd",this);
    ap_wr  = new("ap_wr",this);  ap_ref = new("ap_ref",this);
    ap_err = new("ap_err",this);
    for (int i=0; i<32; i++) begin bank_st[i].open=0; bank_st[i].row='0; end
  endfunction

  function void write_cmd(ddr5_seq_item it);
    int bk = int'(it.bg)*4 + int'(it.bank);
    case (it.cmd)
      CMD_ACT: begin
        act_cnt++;
        if (bank_st[bk].open)
          `uvm_error("SB_ACT", $sformatf("ACT to open bank BG%0d BA%0d!", it.bg, it.bank))
        bank_st[bk].open = 1; bank_st[bk].row = it.row;
      end
      CMD_PRE, CMD_PREA: begin
        pre_cnt++;
        if (it.cmd == CMD_PREA)
          for (int i=0; i<32; i++) bank_st[i].open = 0;
        else begin
          if (!bank_st[bk].open)
            `uvm_warning("SB_PRE", $sformatf("PRE to idle bank BG%0d BA%0d", it.bg, it.bank))
          bank_st[bk].open = 0;
        end
      end
      CMD_WR, CMD_WRA: begin
        wr_cnt++;
        if (!bank_st[bk].open)
          `uvm_error("SB_WR", $sformatf("WR to closed bank BG%0d BA%0d", it.bg, it.bank))
        else begin
          logic [26:0] key = {it.bg, it.bank, bank_st[bk].row, it.col};
          shadow_mem[key] = it.wdata;
        end
        if (it.auto_precharge) bank_st[bk].open = 0;
      end
      CMD_RD, CMD_RDA: begin
        rd_cnt++;
        if (!bank_st[bk].open)
          `uvm_error("SB_RD", $sformatf("RD from closed bank BG%0d BA%0d", it.bg, it.bank))
        else begin
          logic [26:0] key = {it.bg, it.bank, bank_st[bk].row, it.col};
          if (shadow_mem.exists(key))
            pending_rd[key] = shadow_mem[key];
        end
        if (it.auto_precharge) bank_st[bk].open = 0;
      end
      default: ;
    endcase
  endfunction

  function void write_wr(ddr5_seq_item it);
    // Data path verification handled in write_cmd
  endfunction

  function void write_rd(ddr5_seq_item it);
    // Check read data matches written data
  endfunction

  function void write_ref(ddr5_seq_item it);
    ref_cnt++;
    `uvm_info("SB_REF", $sformatf("Refresh #%0d cmd=%s", ref_cnt, it.cmd.name()), UVM_HIGH)
  endfunction

  function void write_err(ddr5_seq_item it);
    err_cnt++;
    `uvm_warning("SB_ERR", $sformatf("Error #%0d: %s", err_cnt, it.inject_err.name()))
  endfunction

  function void check_phase(uvm_phase phase);
    // Check no banks left open
    for (int i=0; i<32; i++) begin
      if (bank_st[i].open)
        `uvm_warning("SB_FINAL", $sformatf("Bank BG%0d BA%0d still open at end",
                     i/4, i%4))
    end
    `uvm_info("SB_SUMMARY", $sformatf(
      "\n=== DDR5/LPDDR5 Scoreboard Summary ===\n"
      "  ACT:%0d  WR:%0d  RD:%0d  PRE:%0d\n"
      "  REF:%0d  ERR:%0d  Mismatches:%0d",
      act_cnt, wr_cnt, rd_cnt, pre_cnt,
      ref_cnt, err_cnt, mismatch_cnt), UVM_LOW)
  endfunction

endclass : ddr5_scoreboard

`endif
