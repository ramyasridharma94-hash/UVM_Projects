`ifndef DDR5_MRS_SEQ_SV
`define DDR5_MRS_SEQ_SV
class ddr5_mrs_seq extends ddr5_base_seq;
  `uvm_object_utils(ddr5_mrs_seq)
  import ddr5_pkg::*;
  ddr5_mode_regs_t target_mrs;

  function new(string name="ddr5_mrs_seq"); super.new(name); endfunction

  task body();
    // Program all key mode registers in order
    logic [7:0] mr_list[$] = '{8'd0,8'd2,8'd3,8'd5,8'd6,8'd7,8'd8,8'd10,8'd13,8'd15,8'd17};
    logic [7:0] mr_vals[$] = '{
      8'h14, // MR0: BL8, CL=20
      8'h00, // MR2: Write leveling off
      8'h01, // MR3: Gear-down enabled
      8'hCC, // MR5: ODT
      8'h04, // MR6: RTT_NOM_WR
      8'h04, // MR7: RTT_NOM_RD
      8'h40, // MR8: VREF DQ
      8'h04, // MR10: tODT
      8'h04, // MR13: CA parity enable
      8'h01, // MR15: ECC SEC/DED
      8'h04  // MR17: DQ driver impedance
    };
    for (int i = 0; i < mr_list.size(); i++) begin
      ddr5_seq_item it = ddr5_seq_item::type_id::create($sformatf("mrs_%0d",i));
      start_item(it);
      if (!it.randomize() with { cmd==CMD_MRS; mr_addr==mr_list[i]; mr_data==mr_vals[i]; })
        `uvm_fatal("RAND","ddr5_mrs_seq")
      finish_item(it);
      `uvm_info("MRS_SEQ",$sformatf("MR%0d = 0x%02h", mr_list[i], mr_vals[i]), UVM_MEDIUM)
    end
  endtask
endclass
`endif
