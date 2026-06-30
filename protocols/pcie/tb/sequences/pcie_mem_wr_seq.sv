`ifndef PCIE_MEM_WR_SEQ_SV
`define PCIE_MEM_WR_SEQ_SV

// Memory Write sequence — MWr32, MWr64, various sizes
class pcie_mem_wr_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_mem_wr_seq)
  import pcie_pkg::*;

  rand bit use_64bit;
  rand bit poison_ep;   // inject EP bit

  function new(string name = "pcie_mem_wr_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;
    for (int i = 0; i < num_pkts; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("mwr_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type  inside {MWr32, MWr64};
          (use_64bit)  -> tlp_type == MWr64;
          (!use_64bit) -> tlp_type == MWr32;
          length    inside {[1:32]};
          first_be  != 4'h0;
          ep        == poison_ep;
      })
        `uvm_fatal("RAND", "pcie_mem_wr_seq: randomization failed")
      finish_item(item);
      `uvm_info("MWR_SEQ", $sformatf("[%0d] %s", i, item.convert2string()), UVM_HIGH)
    end
  endtask

endclass : pcie_mem_wr_seq

// Directed: write known pattern to fixed address
class pcie_mem_wr_directed_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_mem_wr_directed_seq)
  import pcie_pkg::*;
  logic [63:0] target_addr  = 64'hDEAD_BEEF_0000_0000;
  logic [63:0] write_data   = 64'hA5A5_5A5A_A5A5_5A5A;

  function new(string name = "pcie_mem_wr_directed_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create("mwr64_dir");
    start_item(item);
    if (!item.randomize() with {
        tlp_type == MWr64;
        addr     == target_addr;
        length   == 2;
        first_be == 4'hF;
        last_be  == 4'hF;
        data_lo  == write_data;
        ep       == 0;
    })
      `uvm_fatal("RAND", "pcie_mem_wr_directed_seq: randomize failed")
    finish_item(item);
    `uvm_info("MWR64_DIR",
      $sformatf("MWr64 to 0x%016h data=0x%016h", target_addr, write_data), UVM_LOW)
  endtask

endclass : pcie_mem_wr_directed_seq

`endif
