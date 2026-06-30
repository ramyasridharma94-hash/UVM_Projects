`ifndef PCIE_VIRTUAL_CH_TEST_SV
`define PCIE_VIRTUAL_CH_TEST_SV

// Virtual Channel test — sends TLPs across all 8 TCs (TC0-TC7)
// Tests TC-to-VC mapping and ordering within each VC
class pcie_virtual_ch_test extends pcie_base_test;
  `uvm_component_utils(pcie_virtual_ch_test)
  import pcie_pkg::*;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_mem_wr_seq wr_seq;
    pcie_mem_rd_seq rd_seq;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== Virtual Channel (TC0-TC7) Test ===", UVM_LOW)

    // Send writes on all 8 TCs
    for (int tc = 0; tc < 8; tc++) begin
      pcie_tlp_seq_item item;
      // Direct the agent to use a specific TC
      wr_seq = pcie_mem_wr_seq::type_id::create($sformatf("vc_wr_tc%0d", tc));
      wr_seq.num_pkts = 4;
      // We use a virtual sequence override approach via factory
      begin
        // Per-TC write burst via directed item
        for (int p = 0; p < 4; p++) begin
          item = pcie_tlp_seq_item::type_id::create($sformatf("tc%0d_wr_%0d", tc, p));
          wr_seq.start_item(item);
          if (!item.randomize() with {
              tlp_type inside {MWr32, MWr64};
              tc       == 3'(tc);
              length   inside {[1:8]};
              first_be == 4'hF;
          })
            `uvm_fatal("RAND", $sformatf("VC test TC%0d randomize failed", tc))
          wr_seq.finish_item(item);
        end
      end
      `uvm_info("VC_TEST", $sformatf("TC%0d: 4 MWr sent", tc), UVM_MEDIUM)
    end

    // Send reads on all 8 TCs
    for (int tc = 0; tc < 8; tc++) begin
      pcie_tlp_seq_item item;
      rd_seq = pcie_mem_rd_seq::type_id::create($sformatf("vc_rd_tc%0d", tc));
      for (int p = 0; p < 4; p++) begin
        item = pcie_tlp_seq_item::type_id::create($sformatf("tc%0d_rd_%0d", tc, p));
        rd_seq.start_item(item);
        if (!item.randomize() with {
            tlp_type inside {MRd32, MRd64};
            tc       == 3'(tc);
            length   inside {[1:4]};
            first_be != 4'h0;
        })
          `uvm_fatal("RAND", $sformatf("VC test TC%0d read randomize failed", tc))
        rd_seq.finish_item(item);
      end
      `uvm_info("VC_TEST", $sformatf("TC%0d: 4 MRd sent", tc), UVM_MEDIUM)
    end

    // Mixed TC traffic (ordering stress)
    `uvm_info("VC_TEST", "Mixed TC ordering stress", UVM_LOW)
    fork
      begin // TC0 stream
        pcie_mem_wr_seq s = pcie_mem_wr_seq::type_id::create("tc0_stream");
        s.num_pkts = 16;
        s.start(env.agent.sequencer);
      end
    join

    #300ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_virtual_ch_test

`endif
