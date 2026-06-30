`ifndef APB_BRIDGE_ERROR_SEQ_SV
`define APB_BRIDGE_ERROR_SEQ_SV
class bridge_error_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_error_seq)
  import pcie_pkg::*;
  function new(string name="bridge_error_seq"); super.new(name); endfunction
  task body();
    // pslverr injection via special data value
    for (int i = 0; i < 4; i++) begin
      pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create($sformatf("slverr_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type==MWr32; inject_slverr==1; data==32'hDEAD_ERR; })
        `uvm_fatal("RAND","error_seq slverr failed")
      finish_item(it);
      `uvm_info("ERR_SEQ","Injected pslverr via pwdata==DEAD_ERR",UVM_LOW)
    end
    // Normal recovery
    for (int i = 0; i < 4; i++) begin
      pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create($sformatf("recov_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type inside {MRd32,MWr32}; inject_slverr==0; })
        `uvm_fatal("RAND","error_seq recovery failed")
      finish_item(it);
    end
  endtask
endclass
`endif
