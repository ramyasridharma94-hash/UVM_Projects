`ifndef APB_BRIDGE_MEM_RD_SEQ_SV
`define APB_BRIDGE_MEM_RD_SEQ_SV
class bridge_mem_rd_seq extends bridge_base_seq;
  `uvm_object_utils(bridge_mem_rd_seq)
  import pcie_pkg::*;
  function new(string name="bridge_mem_rd_seq"); super.new(name); endfunction
  task body();
    for (int i = 0; i < num_pkts; i++) begin
      pcie_tlp_seq_item it = pcie_tlp_seq_item::type_id::create($sformatf("memrd_%0d",i));
      start_item(it);
      if (!it.randomize() with { tlp_type==MRd32; addr[1:0]==2'b0; first_be inside {4'hF,4'h3,4'h1}; inject_slverr==0; })
        `uvm_fatal("RAND","mem_rd_seq failed")
      finish_item(it);
    end
  endtask
endclass
`endif
