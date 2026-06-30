`ifndef APB_PCIE_TLP_SEQ_ITEM_SV
`define APB_PCIE_TLP_SEQ_ITEM_SV

class pcie_tlp_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(pcie_tlp_seq_item)
    `uvm_field_enum(tlp_type_e, tlp_type, UVM_ALL_ON)
    `uvm_field_int(addr,      UVM_ALL_ON)
    `uvm_field_int(length,    UVM_ALL_ON)
    `uvm_field_int(tag,       UVM_ALL_ON)
    `uvm_field_int(req_id,    UVM_ALL_ON)
    `uvm_field_int(first_be,  UVM_ALL_ON)
    `uvm_field_int(data,      UVM_ALL_ON)
    `uvm_field_int(inject_slverr, UVM_ALL_ON)
  `uvm_object_utils_end

  import pcie_pkg::*;

  rand tlp_type_e  tlp_type;
  rand logic [31:0] addr;
  rand logic [9:0]  length;
  rand logic [7:0]  tag;
  rand logic [15:0] req_id;
  rand logic [3:0]  first_be;
  rand logic [31:0] data;
  rand bit          inject_slverr;

  // APB only supports single DW, single-beat transfers
  constraint c_tlp_types { tlp_type inside {CfgRd0, CfgWr0, MRd32, MWr32}; }
  constraint c_length_one { length == 1; }
  constraint c_addr_32b   { addr[31:12] inside {[0:20'hFFFFF]}; }
  constraint c_cfg_addr   {
    (tlp_type inside {CfgRd0, CfgWr0}) -> addr[31:12] == 20'h0;
  }
  constraint c_fbe_nonzero { first_be != 4'h0; }
  constraint c_slverr_rare { inject_slverr dist {0 := 90, 1 := 10}; }

  function new(string name = "pcie_tlp_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("type=%-8s addr=0x%08h len=%0d tag=0x%02h be=%04b data=0x%08h slverr=%0b",
                     tlp_type.name(), addr, length, tag, first_be, data, inject_slverr);
  endfunction

  function bit is_write();
    return tlp_type inside {MWr32, CfgWr0};
  endfunction

endclass : pcie_tlp_seq_item

`endif
