`ifndef AXI4_BRIDGE_CFG_SEQ_SV
`define AXI4_BRIDGE_CFG_SEQ_SV
class bridge_cfg_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_cfg_seq)
  import pcie_pkg::*;
  function new(string name="bridge_cfg_seq"); super.new(name); endfunction
  task body();
    for (int i=0; i<num_pkts; i++) begin
      pcie_tlp_seq_item it=pcie_tlp_seq_item::type_id::create($sformatf("cfg_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type inside {CfgRd0,CfgWr0}; length==1; addr[63:12]==0; first_be==4'hF; })
        `uvm_fatal("RAND","bridge_cfg_seq failed")
      finish_item(it);
    end
  endtask
endclass
`endif
