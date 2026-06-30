`ifndef AHB_BRIDGE_IO_SEQ_SV
`define AHB_BRIDGE_IO_SEQ_SV
class bridge_io_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_io_seq)
  import pcie_pkg::*;
  function new(string name="bridge_io_seq"); super.new(name); endfunction
  task body();
    for (int i=0; i<num_pkts; i++) begin
      pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create($sformatf("io_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type inside {IORd,IOWr}; length==1; first_be==4'hF; addr[63:32]==0; })
        `uvm_fatal("RAND","bridge_io_seq failed")
      finish_item(it);
      `uvm_info("IO_SEQ",$sformatf("[%0d] %s",i,it.convert2string()),UVM_MEDIUM)
    end
  endtask
endclass
`endif
