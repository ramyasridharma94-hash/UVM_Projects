`ifndef AXI4_BRIDGE_MIXED_SEQ_SV
`define AXI4_BRIDGE_MIXED_SEQ_SV
class bridge_mixed_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_mixed_seq)
  import pcie_pkg::*;
  function new(string name="bridge_mixed_seq"); super.new(name); endfunction
  task body();
    for (int i=0; i<num_pkts; i++) begin
      pcie_tlp_seq_item it=pcie_tlp_seq_item::type_id::create($sformatf("mix_%0d",i));
      start_item(it);
      if (!it.randomize()) `uvm_fatal("RAND","bridge_mixed_seq failed")
      finish_item(it);
    end
  endtask
endclass
`endif
