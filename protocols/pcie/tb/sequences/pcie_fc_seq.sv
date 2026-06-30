`ifndef PCIE_FC_SEQ_SV
`define PCIE_FC_SEQ_SV

// Flow Control sequence — tests FC credit initialization, updates, and exhaustion
class pcie_fc_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_fc_seq)
  import pcie_pkg::*;

  // Fill the TX with enough writes to stress FC credit limits
  int unsigned burst_count = 16;

  function new(string name = "pcie_fc_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;

    `uvm_info("FC_SEQ", $sformatf("FC stress burst: %0d MWr TLPs", burst_count), UVM_LOW)
    // Rapid-fire posted writes — stresses posted FC credits
    for (int i = 0; i < burst_count; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("fc_mwr_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type  inside {MWr32, MWr64};
          length    inside {[1:8]};
          first_be  == 4'hF;
          inject_err == ERR_NONE;
      })
        `uvm_fatal("RAND", "pcie_fc_seq: MWr randomize failed")
      finish_item(item);
    end

    // Non-posted stress — MRd bursts
    `uvm_info("FC_SEQ", "FC stress: NP MRd burst", UVM_LOW)
    for (int i = 0; i < burst_count/2; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("fc_mrd_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type  inside {MRd32, MRd64};
          length    inside {[1:4]};
          first_be  != 4'h0;
      })
        `uvm_fatal("RAND", "pcie_fc_seq: MRd randomize failed")
      finish_item(item);
    end

    // Completion stress — CplD back-to-back
    `uvm_info("FC_SEQ", "FC stress: CplD burst", UVM_LOW)
    for (int i = 0; i < burst_count/2; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("fc_cpl_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type    == CplD;
          cpl_status  == CPL_SC;
          length      inside {[1:8]};
          cpl_byte_cnt inside {[4:32]};
      })
        `uvm_fatal("RAND", "pcie_fc_seq: CplD randomize failed")
      finish_item(item);
    end

    `uvm_info("FC_SEQ", "Flow control sequence complete", UVM_LOW)
  endtask

endclass : pcie_fc_seq

// FC exhaustion test — deliberately exhaust credits then recover
class pcie_fc_exhaust_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_fc_exhaust_seq)
  import pcie_pkg::*;

  function new(string name = "pcie_fc_exhaust_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;
    `uvm_info("FC_EXH", "Exhausting posted credits with max-payload MWr", UVM_LOW)
    // Send max-size writes to exhaust posted data credits
    for (int i = 0; i < 256; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("fc_exh_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type == MWr64;
          length   == 32;      // 128 bytes each
          first_be == 4'hF; last_be == 4'hF;
      })
        `uvm_fatal("RAND", "pcie_fc_exhaust_seq: randomize failed")
      finish_item(item);
    end
    `uvm_info("FC_EXH", "Credit exhaustion sequence complete — expect backpressure", UVM_LOW)
  endtask

endclass : pcie_fc_exhaust_seq

`endif
