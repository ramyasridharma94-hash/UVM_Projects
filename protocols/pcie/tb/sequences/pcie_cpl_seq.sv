`ifndef PCIE_CPL_SEQ_SV
`define PCIE_CPL_SEQ_SV

// Completion sequence — generates Cpl and CplD responses with various statuses
class pcie_cpl_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_cpl_seq)
  import pcie_pkg::*;

  rand bit with_data;
  rand cpl_status_e forced_status;
  bit  force_status = 0;

  function new(string name = "pcie_cpl_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;
    for (int i = 0; i < num_pkts; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("cpl_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type      inside {Cpl, CplD, CplLk, CplDLk};
          (with_data)   -> tlp_type inside {CplD, CplDLk};
          (!with_data)  -> tlp_type inside {Cpl, CplLk};
          cpl_byte_cnt  inside {[1:128]};
          length        inside {[1:32]};
          (force_status) -> cpl_status == forced_status;
      })
        `uvm_fatal("RAND", "pcie_cpl_seq: randomize failed")
      finish_item(item);
      `uvm_info("CPL_SEQ", $sformatf("[%0d] type=%s status=%s tag=0x%02h bcnt=%0d",
                i, item.tlp_type.name(), item.cpl_status.name(),
                item.cpl_tag, item.cpl_byte_cnt), UVM_MEDIUM)
    end
  endtask

endclass : pcie_cpl_seq

// Split completion sequence — multi-part completion for a single request
class pcie_split_cpl_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_split_cpl_seq)
  import pcie_pkg::*;
  int total_bytes = 64;
  logic [7:0] req_tag_in = 8'h00;

  function new(string name = "pcie_split_cpl_seq");
    super.new(name);
  endfunction

  task body();
    int remaining = total_bytes;
    int chunk;
    int pkt_num = 0;
    while (remaining > 0) begin
      chunk = (remaining > 16) ? 16 : remaining;
      pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create($sformatf("scpl_%0d", pkt_num));
      start_item(item);
      if (!item.randomize() with {
          tlp_type     == CplD;
          cpl_status   == CPL_SC;
          cpl_tag      == req_tag_in;
          cpl_byte_cnt == remaining;
          length       == chunk/4;
      })
        `uvm_fatal("RAND", "pcie_split_cpl_seq: randomize failed")
      finish_item(item);
      remaining -= chunk;
      pkt_num++;
      `uvm_info("SCPL_SEQ", $sformatf("Split CplD pkt=%0d remaining=%0d", pkt_num, remaining), UVM_MEDIUM)
    end
  endtask

endclass : pcie_split_cpl_seq

`endif
