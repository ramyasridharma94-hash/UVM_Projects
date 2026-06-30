`ifndef APB_BRIDGE_CFG_RD_SEQ_SV
`define APB_BRIDGE_CFG_RD_SEQ_SV
class bridge_cfg_rd_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_cfg_rd_seq)
  import pcie_pkg::*;
  logic [11:0] cfg_regs[] = '{12'h000,12'h004,12'h008,12'h00C,12'h010,12'h014,12'h034,12'h03C};
  function new(string name="bridge_cfg_rd_seq"); super.new(name); endfunction
  task body();
    for (int i = 0; i < num_pkts; i++) begin
      pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create($sformatf("cfgrd_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type==CfgRd0; addr=={20'h0,cfg_regs[i%cfg_regs.size()]}; first_be==4'hF; })
        `uvm_fatal("RAND","cfg_rd_seq failed")
      finish_item(it);
      `uvm_info("CFG_RD_SEQ",$sformatf("CfgRd reg=0x%03h",cfg_regs[i%cfg_regs.size()]),UVM_MEDIUM)
    end
  endtask
endclass
`endif
