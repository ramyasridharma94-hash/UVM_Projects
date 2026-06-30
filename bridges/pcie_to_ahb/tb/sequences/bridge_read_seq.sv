`ifndef AHB_BRIDGE_READ_SEQ_SV
`define AHB_BRIDGE_READ_SEQ_SV
class bridge_read_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_read_seq)
  import pcie_pkg::*;
  rand bit use_64bit;
  function new(string name="bridge_read_seq"); super.new(name); endfunction
  task body();
    for (int i=0; i<num_pkts; i++) begin
      pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create($sformatf("rd_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type inside {MRd32,MRd64};
          (use_64bit)->tlp_type==MRd64; (!use_64bit)->tlp_type==MRd32;
          length inside {[1:8]}; first_be!=4'h0; })
        `uvm_fatal("RAND","bridge_read_seq failed")
      finish_item(it);
    end
  endtask
endclass
`endif
