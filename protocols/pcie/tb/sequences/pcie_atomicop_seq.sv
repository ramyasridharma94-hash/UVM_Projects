`ifndef PCIE_ATOMICOP_SEQ_SV
`define PCIE_ATOMICOP_SEQ_SV

// AtomicOp sequence — FetchAdd, Swap, CAS (32 and 64-bit)
class pcie_atomicop_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_atomicop_seq)
  import pcie_pkg::*;

  rand bit use_64bit;

  function new(string name = "pcie_atomicop_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;
    tlp_type_e fa, sw, cas;
    fa  = use_64bit ? FetchAdd64 : FetchAdd32;
    sw  = use_64bit ? Swap64     : Swap32;
    cas = use_64bit ? CAS64      : CAS32;

    // FetchAdd
    `uvm_info("ATOM_SEQ", $sformatf("FetchAdd%0s", use_64bit ? "64" : "32"), UVM_LOW)
    item = pcie_tlp_seq_item::type_id::create("fetchadd");
    start_item(item);
    if (!item.randomize() with {
        tlp_type == fa;
        length   == (use_64bit ? 4 : 2);
        data_lo  == 64'h0000_0000_0000_0001;  // operand: add 1
    })
      `uvm_fatal("RAND", "pcie_atomicop_seq: FetchAdd failed")
    finish_item(item);

    // Swap
    `uvm_info("ATOM_SEQ", $sformatf("UnconditionalSwap%0s", use_64bit ? "64" : "32"), UVM_LOW)
    item = pcie_tlp_seq_item::type_id::create("swap");
    start_item(item);
    if (!item.randomize() with {
        tlp_type == sw;
        length   == (use_64bit ? 2 : 1);
        data_lo  == 64'hA5A5_A5A5_A5A5_A5A5;
    })
      `uvm_fatal("RAND", "pcie_atomicop_seq: Swap failed")
    finish_item(item);

    // Compare-and-Swap
    `uvm_info("ATOM_SEQ", $sformatf("CAS%0s", use_64bit ? "64" : "32"), UVM_LOW)
    item = pcie_tlp_seq_item::type_id::create("cas");
    start_item(item);
    if (!item.randomize() with {
        tlp_type == cas;
        length   == (use_64bit ? 4 : 2);
        data_lo  == 64'hDEAD_BEEF_DEAD_BEEF;  // compare value
        data_hi  == 64'hA5A5_5A5A_A5A5_5A5A;  // swap value
    })
      `uvm_fatal("RAND", "pcie_atomicop_seq: CAS failed")
    finish_item(item);

    `uvm_info("ATOM_SEQ", "AtomicOp sequence complete", UVM_LOW)
  endtask

endclass : pcie_atomicop_seq

`endif
