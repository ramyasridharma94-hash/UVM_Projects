`ifndef PCIE_MSI_SEQ_SV
`define PCIE_MSI_SEQ_SV

// MSI/MSI-X interrupt sequence — models interrupt message writes
// MSI is a Memory Write to a system-allocated address
// MSI-X uses a table of (address, data) pairs per vector
class pcie_msi_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_msi_seq)
  import pcie_pkg::*;

  rand bit use_msix;       // 0=MSI, 1=MSI-X
  rand int unsigned num_vectors;

  constraint c_vectors {
    (use_msix) -> num_vectors inside {[1:32]};
    (!use_msix) -> num_vectors inside {[1:8]};
  }

  // MSI capability register addresses (config space)
  localparam logic [11:0] MSI_CAP_CTRL  = 12'h050;
  localparam logic [11:0] MSI_ADDR_LO   = 12'h054;
  localparam logic [11:0] MSI_ADDR_HI   = 12'h058;
  localparam logic [11:0] MSI_DATA      = 12'h05C;
  localparam logic [11:0] MSIX_CAP_CTRL = 12'h070;
  localparam logic [11:0] MSIX_TABLE_OFF= 12'h074;
  localparam logic [11:0] MSIX_PBA_OFF  = 12'h078;

  // MSI-X table base address (system allocates this)
  localparam logic [63:0] MSIX_TABLE_ADDR = 64'hFEE0_0000_0000_0000;

  function new(string name = "pcie_msi_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;

    if (!use_msix) begin
      // --- Program MSI capability ---
      // Write MSI control: enable, vector count = num_vectors, 64-bit capable
      item = pcie_tlp_seq_item::type_id::create("msi_ctrl_wr");
      start_item(item);
      if (!item.randomize() with {
          tlp_type == CfgWr0;
          addr     == {52'h0, MSI_CAP_CTRL};
          length   == 1; first_be == 4'hF; last_be == 4'h0;
          data_lo  == {32'h0, 16'h0000, 3'(num_vectors-1), 4'b0000, 1'b1, 8'h05};
      })
        `uvm_fatal("RAND", "pcie_msi_seq: MSI ctrl write failed")
      finish_item(item);

      // Write MSI address (FEE00000 is typical LAPIC address)
      item = pcie_tlp_seq_item::type_id::create("msi_addr_lo_wr");
      start_item(item);
      if (!item.randomize() with {
          tlp_type == CfgWr0; addr == {52'h0, MSI_ADDR_LO};
          length == 1; first_be == 4'hF;
          data_lo == {32'h0, 32'hFEE0_0000};
      })
        `uvm_fatal("RAND", "pcie_msi_seq: MSI addr lo write failed")
      finish_item(item);

      // Trigger MSI interrupts (MWr to allocated MSI address)
      for (int v = 0; v < num_vectors; v++) begin
        item = pcie_tlp_seq_item::type_id::create($sformatf("msi_trig_%0d", v));
        start_item(item);
        if (!item.randomize() with {
            tlp_type == MWr32;
            addr     == {32'h0, 32'hFEE0_0000};
            length   == 1;
            first_be == 4'hF; last_be == 4'h0;
            data_lo  == {32'h0, 16'h0000, 16'(v)};  // vector number in data
        })
          `uvm_fatal("RAND", "pcie_msi_seq: MSI trigger write failed")
        finish_item(item);
        `uvm_info("MSI_SEQ", $sformatf("MSI vector %0d triggered", v), UVM_MEDIUM)
      end

    end else begin
      // --- Program MSI-X capability ---
      item = pcie_tlp_seq_item::type_id::create("msix_ctrl_wr");
      start_item(item);
      if (!item.randomize() with {
          tlp_type == CfgWr0; addr == {52'h0, MSIX_CAP_CTRL};
          length == 1; first_be == 4'hF;
          data_lo == {32'h0, 1'b1, 1'b0, 14'h0, 11'(num_vectors-1)};
      })
        `uvm_fatal("RAND", "pcie_msi_seq: MSI-X ctrl write failed")
      finish_item(item);

      // Program MSI-X table entries (BAR-mapped, 16 bytes per entry)
      for (int v = 0; v < num_vectors; v++) begin
        logic [63:0] entry_addr = MSIX_TABLE_ADDR + (v * 16);
        // Write Address DW Lo
        item = pcie_tlp_seq_item::type_id::create($sformatf("msix_tbl_alo_%0d", v));
        start_item(item);
        if (!item.randomize() with {
            tlp_type == MWr64; addr == entry_addr;
            length == 1; first_be == 4'hF;
            data_lo == {32'h0, 32'hFEE0_0000};
        })
          `uvm_fatal("RAND", "pcie_msi_seq: MSI-X table addr lo failed")
        finish_item(item);

        // Trigger interrupt via MWr to the vector address
        item = pcie_tlp_seq_item::type_id::create($sformatf("msix_trig_%0d", v));
        start_item(item);
        if (!item.randomize() with {
            tlp_type == MWr32; addr == {32'h0, 32'hFEE0_0000};
            length == 1; first_be == 4'hF;
            data_lo == {32'h0, 16'h0000, 16'(v)};
        })
          `uvm_fatal("RAND", "pcie_msi_seq: MSI-X trigger failed")
        finish_item(item);
        `uvm_info("MSI_SEQ", $sformatf("MSI-X vector %0d triggered", v), UVM_MEDIUM)
      end
    end
    `uvm_info("MSI_SEQ", $sformatf("%s sequence complete (%0d vectors)",
              use_msix ? "MSI-X" : "MSI", num_vectors), UVM_LOW)
  endtask

endclass : pcie_msi_seq

`endif
