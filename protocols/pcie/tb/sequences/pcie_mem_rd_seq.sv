`ifndef PCIE_MEM_RD_SEQ_SV
`define PCIE_MEM_RD_SEQ_SV

// Memory Read sequence — covers MRd32, MRd64, MRdLk variants
class pcie_mem_rd_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_mem_rd_seq)
  import pcie_pkg::*;

  rand bit use_64bit;
  rand bit use_lock;

  function new(string name = "pcie_mem_rd_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;
    for (int i = 0; i < num_pkts; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("mrd_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type inside {MRd32, MRd64, MRdLk32, MRdLk64};
          (use_64bit) -> tlp_type inside {MRd64, MRdLk64};
          (!use_64bit) -> tlp_type inside {MRd32, MRdLk32};
          (use_lock)   -> tlp_type inside {MRdLk32, MRdLk64};
          (!use_lock)  -> tlp_type inside {MRd32, MRd64};
          length inside {[1:16]};
          first_be != 4'h0;
      })
        `uvm_fatal("RAND", "pcie_mem_rd_seq: randomization failed")
      finish_item(item);
      `uvm_info("MRD_SEQ", $sformatf("[%0d] %s", i, item.convert2string()), UVM_MEDIUM)
    end
  endtask

endclass : pcie_mem_rd_seq

// Directed: 32-bit aligned read
class pcie_mem_rd32_directed_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_mem_rd32_directed_seq)
  import pcie_pkg::*;
  logic [31:0] target_addr = 32'hDEAD_0000;
  int          rd_length   = 4; // DWs

  function new(string name = "pcie_mem_rd32_directed_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create("mrd32_dir");
    start_item(item);
    if (!item.randomize() with {
        tlp_type  == MRd32;
        addr      == {32'h0, target_addr};
        length    == rd_length;
        first_be  == 4'hF;
        last_be   == 4'hF;
        tc        == 3'h0;
    })
      `uvm_fatal("RAND", "pcie_mem_rd32_directed_seq: randomize failed")
    finish_item(item);
    `uvm_info("MRD32_DIR", $sformatf("MRd32 to 0x%08h len=%0d", target_addr, rd_length), UVM_LOW)
  endtask

endclass : pcie_mem_rd32_directed_seq

`endif
