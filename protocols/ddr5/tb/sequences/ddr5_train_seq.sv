`ifndef DDR5_TRAIN_SEQ_SV
`define DDR5_TRAIN_SEQ_SV
class ddr5_train_seq extends ddr5_base_seq;
  `uvm_object_utils(ddr5_train_seq)
  import ddr5_pkg::*;

  function new(string name="ddr5_train_seq"); super.new(name); endfunction

  task body();
    train_mode_e train_order[$] = '{
      TRAIN_ZQ, TRAIN_CA, TRAIN_WR_LEVEL,
      TRAIN_RD_DQS, TRAIN_WR_DQ, TRAIN_VREF_DQ, TRAIN_VREF_CA
    };
    foreach (train_order[i]) begin
      ddr5_seq_item it = ddr5_seq_item::type_id::create($sformatf("train_%0d",i));
      start_item(it);
      case (train_order[i])
        TRAIN_ZQ: begin
          if (!it.randomize() with { cmd==CMD_ZQCAL; train_mode==TRAIN_ZQ; })
            `uvm_fatal("RAND","TRAIN_ZQ")
        end
        TRAIN_WR_LEVEL: begin
          if (!it.randomize() with { cmd==CMD_WL; train_mode==TRAIN_WR_LEVEL; })
            `uvm_fatal("RAND","TRAIN_WL")
        end
        TRAIN_CA: begin
          if (!it.randomize() with { cmd==CMD_VrefCA; train_mode==TRAIN_CA; })
            `uvm_fatal("RAND","TRAIN_CA")
        end
        TRAIN_VREF_DQ: begin
          if (!it.randomize() with { cmd==CMD_VrefDQ; train_mode==TRAIN_VREF_DQ; })
            `uvm_fatal("RAND","TRAIN_VREF_DQ")
        end
        default: begin
          if (!it.randomize() with { train_mode==train_order[i]; })
            `uvm_fatal("RAND","TRAIN_default")
        end
      endcase
      finish_item(it);
      `uvm_info("TRAIN_SEQ",$sformatf("Training: %s", train_order[i].name()), UVM_LOW)
    end
    `uvm_info("TRAIN_SEQ","All training modes complete", UVM_LOW)
  endtask
endclass
`endif
