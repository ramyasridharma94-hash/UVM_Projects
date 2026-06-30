`ifndef DDR5_PM_SEQ_SV
`define DDR5_PM_SEQ_SV
class ddr5_pm_seq extends ddr5_base_seq;
  `uvm_object_utils(ddr5_pm_seq)
  import ddr5_pkg::*;

  function new(string name="ddr5_pm_seq"); super.new(name); endfunction

  task body();
    ddr5_seq_item it;
    // Normal writes → PD Entry → PD Exit → Self-Refresh Entry → Exit
    for (int i=0; i<4; i++) begin
      it=ddr5_seq_item::type_id::create($sformatf("pre_pm_%0d",i));
      start_item(it);
      if (!it.randomize() with { cmd==CMD_ACT; }) `uvm_fatal("RAND","pm_seq ACT")
      finish_item(it);
    end
    `uvm_info("PM_SEQ","Entering Power-Down",UVM_LOW)
    it=ddr5_seq_item::type_id::create("pde");
    start_item(it);
    if (!it.randomize() with { cmd==CMD_PDE; }) `uvm_fatal("RAND","PDE")
    finish_item(it);
    `uvm_info("PM_SEQ","Exiting Power-Down",UVM_LOW)
    it=ddr5_seq_item::type_id::create("pdx");
    start_item(it);
    if (!it.randomize() with { cmd==CMD_PDX; }) `uvm_fatal("RAND","PDX")
    finish_item(it);
    `uvm_info("PM_SEQ","Entering Self-Refresh",UVM_LOW)
    it=ddr5_seq_item::type_id::create("sre");
    start_item(it);
    if (!it.randomize() with { cmd==CMD_SRE; }) `uvm_fatal("RAND","SRE")
    finish_item(it);
    `uvm_info("PM_SEQ","Exiting Self-Refresh",UVM_LOW)
    it=ddr5_seq_item::type_id::create("srx");
    start_item(it);
    if (!it.randomize() with { cmd==CMD_SRX; }) `uvm_fatal("RAND","SRX")
    finish_item(it);
    // Post-PM read
    it=ddr5_seq_item::type_id::create("post_pm_act");
    start_item(it);
    if (!it.randomize() with { cmd==CMD_ACT; }) `uvm_fatal("RAND","post ACT")
    finish_item(it);
    `uvm_info("PM_SEQ","Power management sequence complete",UVM_LOW)
  endtask
endclass
`endif
