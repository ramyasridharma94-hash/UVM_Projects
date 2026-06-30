`ifndef PCIE_DLLP_SEQ_ITEM_SV
`define PCIE_DLLP_SEQ_ITEM_SV

// PCIe DLLP Sequence Item — ACK/NAK, Flow Control, Power Management DLLPs
class pcie_dllp_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(pcie_dllp_seq_item)
    `uvm_field_enum(dllp_type_e, dllp_type,      UVM_ALL_ON)
    `uvm_field_int (seq_num,                      UVM_ALL_ON)
    `uvm_field_int (vc_id,                        UVM_ALL_ON)
    `uvm_field_int (hdr_credits,                  UVM_ALL_ON)
    `uvm_field_int (data_credits,                 UVM_ALL_ON)
  `uvm_object_utils_end

  import pcie_pkg::*;

  rand dllp_type_e  dllp_type;
  rand logic [11:0] seq_num;      // for ACK/NAK
  rand logic [2:0]  vc_id;        // virtual channel 0-7
  rand logic [11:0] hdr_credits;  // header FC credits
  rand logic [11:0] data_credits; // data FC credits

  // FC credits are non-zero for UpdateFC
  constraint c_fc_credits {
    (dllp_type inside {DLLP_UpdateFC_P, DLLP_UpdateFC_NP, DLLP_UpdateFC_C}) ->
      (hdr_credits > 0 || data_credits > 0);
  }

  constraint c_vc_range { vc_id inside {[0:7]}; }

  function new(string name = "pcie_dllp_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("dllp=%-20s seq=%04h vc=%0d hdr_cr=%0d dat_cr=%0d",
                     dllp_type.name(), seq_num, vc_id, hdr_credits, data_credits);
  endfunction

endclass : pcie_dllp_seq_item

`endif
