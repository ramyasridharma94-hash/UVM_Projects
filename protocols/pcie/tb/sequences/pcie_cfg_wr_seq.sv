`ifndef PCIE_CFG_WR_SEQ_SV
`define PCIE_CFG_WR_SEQ_SV

// Configuration Write sequence — programs PCIe config registers
class pcie_cfg_wr_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_cfg_wr_seq)
  import pcie_pkg::*;

  rand bit type1;

  function new(string name = "pcie_cfg_wr_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;
    // {reg_addr, write_value}
    logic [11:0] regs  [] = '{12'h004, 12'h010, 12'h014, 12'h018, 12'h03C};
    logic [31:0] vals  [] = '{32'h0007, 32'hFEDC_0000, 32'hFEDC_8000,
                              32'hBEEF_0000, 32'h0000_0101};
    for (int i = 0; i < num_pkts; i++) begin
      int idx = i % regs.size();
      item = pcie_tlp_seq_item::type_id::create($sformatf("cfgwr_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type == (type1 ? CfgWr1 : CfgWr0);
          addr     == {52'h0, regs[idx]};
          length   == 1;
          first_be == 4'hF;
          last_be  == 4'h0;
          data_lo  == {32'h0, vals[idx]};
          tc       == 3'h0;
      })
        `uvm_fatal("RAND", "pcie_cfg_wr_seq: randomize failed")
      finish_item(item);
      `uvm_info("CFG_WR", $sformatf("CfgWr%s reg=0x%03h data=0x%08h",
                type1 ? "1" : "0", regs[idx], vals[idx]), UVM_MEDIUM)
    end
  endtask

endclass : pcie_cfg_wr_seq

`endif
