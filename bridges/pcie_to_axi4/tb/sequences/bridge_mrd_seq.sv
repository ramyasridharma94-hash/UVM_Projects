`ifndef AXI4_BRIDGE_MRD_SEQ_SV
`define AXI4_BRIDGE_MRD_SEQ_SV
class bridge_mrd_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_mrd_seq)
  import pcie_pkg::*;
  rand bit use_64bit;
  function new(string name="bridge_mrd_seq"); super.new(name); endfunction
  task body();
    for (int i=0; i<num_pkts; i++) begin
      pcie_tlp_seq_item it=pcie_tlp_seq_item::type_id::create($sformatf("mrd_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type inside {MRd32,MRd64};
          (use_64bit)->tlp_type==MRd64; (!use_64bit)->tlp_type==MRd32;
          length inside {[1:16]}; first_be!=4'h0; })
        `uvm_fatal("RAND","bridge_mrd_seq failed")
      finish_item(it);
    end
  endtask
endclass
`endif
