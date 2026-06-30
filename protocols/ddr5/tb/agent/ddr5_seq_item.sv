`ifndef DDR5_SEQ_ITEM_SV
`define DDR5_SEQ_ITEM_SV

class ddr5_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(ddr5_seq_item)
    `uvm_field_enum(ddr5_cmd_e,    cmd,         UVM_ALL_ON)
    `uvm_field_enum(burst_len_e,   burst_len,   UVM_ALL_ON)
    `uvm_field_int (bg,                         UVM_ALL_ON)
    `uvm_field_int (bank,                       UVM_ALL_ON)
    `uvm_field_int (row,                        UVM_ALL_ON)
    `uvm_field_int (col,                        UVM_ALL_ON)
    `uvm_field_int (wdata,                      UVM_ALL_ON)
    `uvm_field_int (wmask,                      UVM_ALL_ON)
    `uvm_field_int (mr_addr,                    UVM_ALL_ON)
    `uvm_field_int (mr_data,                    UVM_ALL_ON)
    `uvm_field_enum(refresh_mode_e, ref_mode,   UVM_ALL_ON)
    `uvm_field_enum(train_mode_e,   train_mode, UVM_ALL_ON)
    `uvm_field_enum(ddr5_error_e,   inject_err, UVM_ALL_ON)
    `uvm_field_enum(power_state_e,  pwr_state,  UVM_ALL_ON)
    `uvm_field_int (auto_precharge,             UVM_ALL_ON)
  `uvm_object_utils_end

  import ddr5_pkg::*;

  // -----------------------------------------------------------------------
  // Randomizable fields
  // -----------------------------------------------------------------------
  rand ddr5_cmd_e    cmd;
  rand burst_len_e   burst_len;
  rand logic [2:0]   bg;         // Bank group 0-7
  rand logic [1:0]   bank;       // Bank 0-3
  rand logic [16:0]  row;        // Row address
  rand logic [9:0]   col;        // Column address (aligned to BL)
  rand logic [255:0] wdata;      // BL8 × 32-bit = 256 bits
  rand logic [31:0]  wmask;      // Write mask (1=mask)
  rand logic [7:0]   mr_addr;    // Mode register address
  rand logic [7:0]   mr_data;    // Mode register data
  rand refresh_mode_e ref_mode;
  rand train_mode_e  train_mode;
  rand ddr5_error_e  inject_err;
  rand power_state_e pwr_state;
  rand bit           auto_precharge;

  // -----------------------------------------------------------------------
  // Constraints
  // -----------------------------------------------------------------------
  constraint c_cmd_valid {
    cmd inside {CMD_ACT, CMD_PRE, CMD_PREA, CMD_RD, CMD_RDA,
                CMD_WR,  CMD_WRA, CMD_MRS,  CMD_REF, CMD_REFPB,
                CMD_PDE, CMD_PDX, CMD_SRE,  CMD_SRX,
                CMD_ZQCAL, CMD_VrefDQ, CMD_WL, CMD_NOP};
  }
  constraint c_bg_range  { bg   inside {[0:7]};  }
  constraint c_bank_range{ bank inside {[0:3]};  }
  constraint c_col_align { col[1:0] == 2'b00;    }  // DW-aligned
  constraint c_no_err    { inject_err == DDR5_ERR_NONE; }
  constraint c_no_train  { train_mode == TRAIN_NONE; }
  constraint c_bl_dist   { burst_len dist {BL8:=70, BL16:=20, BC4:=10}; }
  constraint c_wmask_rare{ wmask dist {32'h0:=80, [32'h1:32'hFF]:=20}; }

  // ACT/PRE/RD/WR need BG/bank targeting; REF/MRS don't care
  constraint c_rw_cmd {
    (cmd inside {CMD_ACT, CMD_PRE, CMD_RD, CMD_RDA, CMD_WR, CMD_WRA})
      -> (bg inside {[0:7]} && bank inside {[0:3]});
  }
  // MRS uses mr_addr/mr_data
  constraint c_mrs_addr { (cmd == CMD_MRS) -> mr_addr inside {8'd0,8'd2,8'd3,8'd5,8'd6,8'd8,8'd13,8'd15}; }
  // Auto-precharge only for RD/WR
  constraint c_ap {
    (auto_precharge == 1) -> cmd inside {CMD_RD, CMD_WR};
    (cmd == CMD_RDA || cmd == CMD_WRA) -> auto_precharge == 1;
  }

  // -----------------------------------------------------------------------
  function new(string name = "ddr5_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf(
      "cmd=%-10s BG%0d.BA%0d row=0x%05h col=0x%03h BL=%s ap=%0b err=%s train=%s",
      cmd.name(), bg, bank, row, col, burst_len.name(),
      auto_precharge, inject_err.name(), train_mode.name());
  endfunction

  function bit is_write();
    return cmd inside {CMD_WR, CMD_WRA};
  endfunction

  function bit is_read();
    return cmd inside {CMD_RD, CMD_RDA};
  endfunction

  function bit needs_open_row();
    return cmd inside {CMD_RD, CMD_RDA, CMD_WR, CMD_WRA, CMD_PRE};
  endfunction

endclass : ddr5_seq_item

`endif
