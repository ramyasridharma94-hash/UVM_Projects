`ifndef DDR5_LPDDR5_SEQ_SV
`define DDR5_LPDDR5_SEQ_SV
// LPDDR5-specific sequence: dual-channel, WCK ratio, DPD, PASR, MPC commands
class ddr5_lpddr5_seq extends ddr5_base_seq;
  `uvm_object_utils(ddr5_lpddr5_seq)
  import ddr5_pkg::*;
  rand bit use_dpd;    // Deep Power-Down
  rand bit use_pasr;   // Partial Array Self-Refresh
  rand bit dual_ch;    // Dual-channel interleaved

  function new(string name="ddr5_lpddr5_seq"); super.new(name); endfunction

  task body();
    ddr5_seq_item it;
    `uvm_info("LP5_SEQ",$sformatf("LPDDR5: dpd=%0b pasr=%0b dual_ch=%0b",
              use_dpd, use_pasr, dual_ch), UVM_LOW)

    // LPDDR5 init via MPC (Multi-Purpose Command) → SetFSP (Frequency Set Point)
    it=ddr5_seq_item::type_id::create("mpc_setfsp");
    start_item(it);
    if (!it.randomize() with { cmd==CMD_MRS; mr_addr==8'h00; mr_data==8'h01; })
      `uvm_fatal("RAND","LP5 SetFSP")
    finish_item(it);

    // Dual-channel ACT/WR/RD sequence (CH0 and CH1 interleaved)
    for (int i=0; i<num_ops; i++) begin
      int ch = dual_ch ? (i%2) : 0;
      // ACT on channel
      it=ddr5_seq_item::type_id::create($sformatf("lp5_act_%0d",i));
      start_item(it);
      if (!it.randomize() with { cmd==CMD_ACT; bg[2]==ch[0]; })
        `uvm_fatal("RAND","LP5 ACT")
      finish_item(it);
      // WR
      it=ddr5_seq_item::type_id::create($sformatf("lp5_wr_%0d",i));
      start_item(it);
      if (!it.randomize() with { cmd==CMD_WR; bg[2]==ch[0]; burst_len==BL16; })
        `uvm_fatal("RAND","LP5 WR BL16")
      finish_item(it);
      `uvm_info("LP5_SEQ",$sformatf("CH%0d BL16 WR [%0d]",ch,i),UVM_MEDIUM)
    end

    if (use_dpd) begin
      `uvm_info("LP5_SEQ","DPD Entry",UVM_LOW)
      it=ddr5_seq_item::type_id::create("dpd_entry");
      start_item(it);
      if (!it.randomize() with { cmd==CMD_SRE; pwr_state==PWR_DPD; })
        `uvm_fatal("RAND","DPD")
      finish_item(it);
      it=ddr5_seq_item::type_id::create("dpd_exit");
      start_item(it);
      if (!it.randomize() with { cmd==CMD_SRX; }) `uvm_fatal("RAND","DPD_exit")
      finish_item(it);
    end

    if (use_pasr) begin
      `uvm_info("LP5_SEQ","PASR Entry (half-array)",UVM_LOW)
      it=ddr5_seq_item::type_id::create("pasr");
      start_item(it);
      if (!it.randomize() with { cmd==CMD_MRS; mr_addr==8'h04; mr_data==8'h01; pwr_state==PWR_PASR; })
        `uvm_fatal("RAND","PASR")
      finish_item(it);
    end
    `uvm_info("LP5_SEQ","LPDDR5 sequence complete",UVM_LOW)
  endtask
endclass
`endif
