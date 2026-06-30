`ifndef DDR5_COVERAGE_SV
`define DDR5_COVERAGE_SV

class ddr5_coverage extends uvm_subscriber #(ddr5_seq_item);
  `uvm_component_utils(ddr5_coverage)
  import ddr5_pkg::*;
  ddr5_seq_item item;

  // Command type coverage
  covergroup cg_commands;
    cp: coverpoint item.cmd {
      bins act  = {CMD_ACT};   bins pre  = {CMD_PRE};  bins prea = {CMD_PREA};
      bins rd   = {CMD_RD};    bins rda  = {CMD_RDA};
      bins wr   = {CMD_WR};    bins wra  = {CMD_WRA};
      bins ref  = {CMD_REF};   bins rpb  = {CMD_REFPB};bins rsb  = {CMD_REFSB};
      bins mrs  = {CMD_MRS};   bins mrr  = {CMD_MRR};
      bins pde  = {CMD_PDE};   bins pdx  = {CMD_PDX};
      bins sre  = {CMD_SRE};   bins srx  = {CMD_SRX};
      bins zqcal= {CMD_ZQCAL}; bins nop  = {CMD_NOP};
      bins wl   = {CMD_WL};    bins vdq  = {CMD_VrefDQ};
    }
  endgroup

  // Burst length coverage
  covergroup cg_burst_len;
    cp: coverpoint item.burst_len {
      bins bl8  = {BL8}; bins bl16 = {BL16}; bins bc4 = {BC4};
    }
  endgroup

  // Bank group coverage (all 8 bank groups must be exercised)
  covergroup cg_bank_group;
    cp_bg: coverpoint item.bg { bins bg[8] = {[3'h0:3'h7]}; }
    cp_bk: coverpoint item.bank { bins bk[4] = {[2'h0:2'h3]}; }
    cx: cross cp_bg, cp_bk;
  endgroup

  // Refresh mode coverage
  covergroup cg_refresh_mode;
    cp: coverpoint item.ref_mode {
      bins normal  = {REF_NORMAL};  bins fgr2x = {REF_FGR_2X};
      bins fgr4x   = {REF_FGR_4X}; bins pbr   = {REF_PBR};
      bins sbr     = {REF_SBR};
    }
  endgroup

  // Training coverage
  covergroup cg_training;
    cp: coverpoint item.train_mode {
      bins none    = {TRAIN_NONE};   bins wl    = {TRAIN_WR_LEVEL};
      bins rd_dqs  = {TRAIN_RD_DQS}; bins wr_dq = {TRAIN_WR_DQ};
      bins ca      = {TRAIN_CA};     bins vdq   = {TRAIN_VREF_DQ};
      bins vca     = {TRAIN_VREF_CA};bins zq    = {TRAIN_ZQ};
    }
  endgroup

  // Error coverage
  covergroup cg_errors;
    cp: coverpoint item.inject_err {
      bins none     = {DDR5_ERR_NONE};    bins parity = {DDR5_ERR_PARITY};
      bins ecc_sbe  = {DDR5_ERR_ECC_SBE}; bins ecc_dbe= {DDR5_ERR_ECC_DBE};
      bins wr_crc   = {DDR5_ERR_WR_CRC};  bins rd_crc = {DDR5_ERR_RD_CRC};
      bins alert    = {DDR5_ERR_ALERT};
    }
  endgroup

  // Power state coverage
  covergroup cg_power;
    cp: coverpoint item.pwr_state {
      bins normal = {PWR_NORMAL}; bins pd   = {PWR_PD};
      bins sref   = {PWR_SREF};   bins dpd  = {PWR_DPD};
      bins pasr   = {PWR_PASR};
    }
  endgroup

  // Auto-Precharge × RW cross
  covergroup cg_ap_cross;
    cp_cmd: coverpoint item.cmd { bins rd={CMD_RD,CMD_RDA}; bins wr={CMD_WR,CMD_WRA}; }
    cp_ap:  coverpoint item.auto_precharge;
    cx: cross cp_cmd, cp_ap;
  endgroup

  // MR address coverage
  covergroup cg_mr_addr;
    cp: coverpoint item.mr_addr {
      bins mr0={8'd0}; bins mr2={8'd2}; bins mr3={8'd3}; bins mr5={8'd5};
      bins mr6={8'd6}; bins mr8={8'd8}; bins mr13={8'd13}; bins mr15={8'd15};
      bins other=default;
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_commands   = new(); cg_burst_len = new();
    cg_bank_group = new(); cg_refresh_mode = new();
    cg_training   = new(); cg_errors    = new();
    cg_power      = new(); cg_ap_cross  = new();
    cg_mr_addr    = new();
  endfunction

  function void write(ddr5_seq_item t);
    item = t;
    cg_commands.sample();   cg_burst_len.sample();
    cg_bank_group.sample(); cg_refresh_mode.sample();
    cg_training.sample();   cg_errors.sample();
    cg_power.sample();      cg_ap_cross.sample();
    cg_mr_addr.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf(
      "\n=== DDR5/LPDDR5 Coverage Summary ===\n"
      "  Commands    : %.1f%%\n  Burst Length: %.1f%%\n"
      "  BG×Bank     : %.1f%%\n  Refresh Mode: %.1f%%\n"
      "  Training    : %.1f%%\n  Errors      : %.1f%%\n"
      "  Power State : %.1f%%\n  AP Cross    : %.1f%%\n"
      "  MR Addr     : %.1f%%",
      cg_commands.get_inst_coverage(),   cg_burst_len.get_inst_coverage(),
      cg_bank_group.get_inst_coverage(), cg_refresh_mode.get_inst_coverage(),
      cg_training.get_inst_coverage(),   cg_errors.get_inst_coverage(),
      cg_power.get_inst_coverage(),      cg_ap_cross.get_inst_coverage(),
      cg_mr_addr.get_inst_coverage()), UVM_LOW)
  endfunction

endclass : ddr5_coverage

`endif
