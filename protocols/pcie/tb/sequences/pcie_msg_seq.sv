`ifndef PCIE_MSG_SEQ_SV
`define PCIE_MSG_SEQ_SV

// Message TLP sequence — PME, INTx, Vendor-Defined, Slot Power, etc.
class pcie_msg_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_msg_seq)
  import pcie_pkg::*;

  typedef enum {
    MSG_ASSERT_INTA  = 0,
    MSG_DEASSERT_INTA,
    MSG_PME,
    MSG_PME_TO_ACK,
    MSG_ERR_COR,
    MSG_ERR_NONFATAL,
    MSG_ERR_FATAL,
    MSG_SLOT_POWER_LMT,
    MSG_VENDOR_TYPE0,
    MSG_UNLOCK
  } msg_code_e;

  rand msg_code_e msg_sel;

  // MSG code values per PCIe spec Table 2-19
  function automatic logic [2:0] get_msg_code(msg_code_e sel);
    case (sel)
      MSG_ASSERT_INTA:   return 3'h0;
      MSG_DEASSERT_INTA: return 3'h4;
      MSG_PME:           return 3'h3;
      MSG_PME_TO_ACK:    return 3'h1;
      MSG_ERR_COR:       return 3'h0;
      MSG_ERR_NONFATAL:  return 3'h1;
      MSG_ERR_FATAL:     return 3'h3;
      MSG_SLOT_POWER_LMT:return 3'h2;
      MSG_VENDOR_TYPE0:  return 3'h7;
      MSG_UNLOCK:        return 3'h0;
      default:           return 3'h0;
    endcase
  endfunction

  function new(string name = "pcie_msg_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;
    for (int i = 0; i < num_pkts; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("msg_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type inside {Msg, MsgD};
          length   inside {[0:4]};
          tc       == 3'h0;
      })
        `uvm_fatal("RAND", "pcie_msg_seq: randomize failed")
      // Override msg_code with legal value
      item.msg_code = get_msg_code(msg_sel);
      finish_item(item);
      `uvm_info("MSG_SEQ", $sformatf("[%0d] type=%s msg_code=0x%01h",
                i, item.tlp_type.name(), item.msg_code), UVM_MEDIUM)
    end
  endtask

endclass : pcie_msg_seq

`endif
