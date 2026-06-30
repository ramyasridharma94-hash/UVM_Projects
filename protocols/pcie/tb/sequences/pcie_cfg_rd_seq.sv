`ifndef PCIE_CFG_RD_SEQ_SV
`define PCIE_CFG_RD_SEQ_SV

// Configuration Read sequence — Type 0 (local), Type 1 (bridge forwarded)
class pcie_cfg_rd_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_cfg_rd_seq)
  import pcie_pkg::*;

  rand bit type1;  // 0=Type0, 1=Type1

  function new(string name = "pcie_cfg_rd_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;
    // Standard PCIe config registers to sweep
    logic [11:0] cfg_regs [] = '{
      12'h000,  // Device/Vendor ID
      12'h004,  // Status/Command
      12'h008,  // Class code / Revision
      12'h00C,  // BIST/Header/Latency/Cache
      12'h010,  // BAR0
      12'h014,  // BAR1
      12'h018,  // BAR2
      12'h02C,  // Subsystem ID
      12'h034,  // Capabilities pointer
      12'h03C   // Interrupt
    };
    for (int i = 0; i < num_pkts; i++) begin
      int idx = i % cfg_regs.size();
      item = pcie_tlp_seq_item::type_id::create($sformatf("cfgrd_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type  == (type1 ? CfgRd1 : CfgRd0);
          addr      == {52'h0, cfg_regs[idx]};
          length    == 1;
          first_be  inside {4'hF, 4'h3, 4'h1};
          last_be   == 4'h0;
          tc        == 3'h0;
      })
        `uvm_fatal("RAND", "pcie_cfg_rd_seq: randomize failed")
      finish_item(item);
      `uvm_info("CFG_RD", $sformatf("CfgRd%s reg=0x%03h be=%04b",
                type1 ? "1" : "0", cfg_regs[idx], item.first_be), UVM_MEDIUM)
    end
  endtask

endclass : pcie_cfg_rd_seq

`endif
