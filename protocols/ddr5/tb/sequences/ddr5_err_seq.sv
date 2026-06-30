`ifndef DDR5_ERR_SEQ_SV
`define DDR5_ERR_SEQ_SV
class ddr5_err_seq extends ddr5_base_seq;
  `uvm_object_utils(ddr5_err_seq)
  import ddr5_pkg::*;
  rand ddr5_error_e err_type;
  constraint c_err_sel {
    err_type inside {DDR5_ERR_PARITY, DDR5_ERR_ECC_SBE, DDR5_ERR_ECC_DBE,
                     DDR5_ERR_WR_CRC, DDR5_ERR_RD_CRC, DDR5_ERR_ALERT};
  }

  function new(string name="ddr5_err_seq"); super.new(name); endfunction

  task body();
    ddr5_seq_item it;
    `uvm_info("ERR_SEQ",$sformatf("Injecting: %s", err_type.name()),UVM_LOW)
    // Good traffic first
    for (int i=0; i<4; i++) begin
      it=ddr5_seq_item::type_id::create($sformatf("good_%0d",i));
      start_item(it);
      if (!it.randomize() with { cmd==CMD_ACT; inject_err==DDR5_ERR_NONE; })
        `uvm_fatal("RAND","err_seq good")
      finish_item(it);
    end
    // Inject error
    it=ddr5_seq_item::type_id::create("err_cmd");
    start_item(it);
    case (err_type)
      DDR5_ERR_PARITY: begin
        if (!it.randomize() with { cmd==CMD_WR; inject_err==DDR5_ERR_PARITY; })
          `uvm_fatal("RAND","PARITY")
      end
      DDR5_ERR_ECC_SBE, DDR5_ERR_ECC_DBE: begin
        if (!it.randomize() with { cmd==CMD_RD; inject_err==err_type; })
          `uvm_fatal("RAND","ECC")
      end
      DDR5_ERR_WR_CRC: begin
        if (!it.randomize() with { cmd==CMD_WR; inject_err==DDR5_ERR_WR_CRC; })
          `uvm_fatal("RAND","WR_CRC")
      end
      default: begin
        if (!it.randomize() with { inject_err==err_type; }) `uvm_fatal("RAND","default_err")
      end
    endcase
    finish_item(it);
    // Recovery
    for (int i=0; i<4; i++) begin
      it=ddr5_seq_item::type_id::create($sformatf("recov_%0d",i));
      start_item(it);
      if (!it.randomize() with { cmd==CMD_REF; inject_err==DDR5_ERR_NONE; })
        `uvm_fatal("RAND","recovery")
      finish_item(it);
    end
    `uvm_info("ERR_SEQ","Error injection sequence complete",UVM_LOW)
  endtask
endclass
`endif
