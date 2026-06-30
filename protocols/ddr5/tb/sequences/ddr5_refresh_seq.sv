`ifndef DDR5_REFRESH_SEQ_SV
`define DDR5_REFRESH_SEQ_SV
class ddr5_refresh_seq extends ddr5_base_seq;
  `uvm_object_utils(ddr5_refresh_seq)
  import ddr5_pkg::*;
  rand refresh_mode_e ref_mode;

  function new(string name="ddr5_refresh_seq"); super.new(name); endfunction

  task body();
    for (int i = 0; i < num_ops; i++) begin
      ddr5_seq_item it = ddr5_seq_item::type_id::create($sformatf("ref_%0d",i));
      start_item(it);
      case (ref_mode)
        REF_NORMAL: begin
          if (!it.randomize() with { cmd==CMD_REF; }) `uvm_fatal("RAND","REF_NORMAL")
        end
        REF_PBR: begin
          if (!it.randomize() with { cmd==CMD_REFPB; }) `uvm_fatal("RAND","REF_PBR")
        end
        REF_SBR: begin
          if (!it.randomize() with { cmd==CMD_REFSB; }) `uvm_fatal("RAND","REF_SBR")
        end
        REF_FGR_2X, REF_FGR_4X: begin
          // FGR: issue multiple REF commands in tREFI/2 or /4 windows
          if (!it.randomize() with { cmd==CMD_REF; }) `uvm_fatal("RAND","FGR")
        end
        default: if (!it.randomize() with { cmd==CMD_REF; }) `uvm_fatal("RAND","def")
      endcase
      finish_item(it);
      `uvm_info("REF_SEQ",$sformatf("Refresh mode=%s [%0d]", ref_mode.name(), i), UVM_MEDIUM)
    end
  endtask
endclass
`endif
