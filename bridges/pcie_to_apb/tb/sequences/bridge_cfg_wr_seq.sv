`ifndef APB_BRIDGE_CFG_WR_SEQ_SV
`define APB_BRIDGE_CFG_WR_SEQ_SV
class bridge_cfg_wr_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_cfg_wr_seq)
  import pcie_pkg::*;
  function new(string name="bridge_cfg_wr_seq"); super.new(name); endfunction
  task body();
    for (int i = 0; i < num_pkts; i++) begin
      pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create($sformatf("cfgwr_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type==CfgWr0; addr[31:12]==20'h0; first_be==4'hF; inject_slverr==0; })
        `uvm_fatal("RAND","cfg_wr_seq failed")
      finish_item(it);
    end
  endtask
endclass
`endif
