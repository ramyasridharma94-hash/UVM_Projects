`ifndef AHB_BRIDGE_WRITE_SEQ_SV
`define AHB_BRIDGE_WRITE_SEQ_SV
class bridge_write_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_write_seq)
  import pcie_pkg::*;
  rand bit use_64bit;
  function new(string name="bridge_write_seq"); super.new(name); endfunction
  task body();
    for (int i=0; i<num_pkts; i++) begin
      pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create($sformatf("wr_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type inside {MWr32,MWr64};
          (use_64bit)->tlp_type==MWr64; (!use_64bit)->tlp_type==MWr32;
          length inside {[1:8]}; first_be==4'hF; })
        `uvm_fatal("RAND","bridge_write_seq failed")
      finish_item(it);
    end
  endtask
endclass
`endif
