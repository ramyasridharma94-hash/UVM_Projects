`ifndef AXI4_PCIE_TLP_SEQ_ITEM_SV
`define AXI4_PCIE_TLP_SEQ_ITEM_SV
class pcie_tlp_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(pcie_tlp_seq_item)
    `uvm_field_enum(tlp_type_e, tlp_type, UVM_ALL_ON)
    `uvm_field_int(addr,     UVM_ALL_ON) `uvm_field_int(length,  UVM_ALL_ON)
    `uvm_field_int(tc,       UVM_ALL_ON) `uvm_field_int(attr,    UVM_ALL_ON)
    `uvm_field_int(req_id,   UVM_ALL_ON) `uvm_field_int(tag,     UVM_ALL_ON)
    `uvm_field_int(first_be, UVM_ALL_ON) `uvm_field_int(last_be, UVM_ALL_ON)
    `uvm_field_int(ep,       UVM_ALL_ON)
    `uvm_field_int(data_lo,  UVM_ALL_ON) `uvm_field_int(data_hi, UVM_ALL_ON)
  `uvm_object_utils_end
  import pcie_pkg::*;

  rand tlp_type_e  tlp_type;
  rand logic [63:0] addr;
  rand logic [9:0]  length;
  rand logic [2:0]  tc;
  rand logic [1:0]  attr;
  rand logic [15:0] req_id;
  rand logic [7:0]  tag;
  rand logic [3:0]  first_be, last_be;
  rand logic        ep;
  rand logic [63:0] data_lo, data_hi;

  constraint c_types { tlp_type inside {MRd32,MRd64,MWr32,MWr64,CfgRd0,CfgWr0,IORd,IOWr}; }
  constraint c_len   { length inside {[1:16]}; }
  constraint c_3dw   { (tlp_type inside {MRd32,MWr32,IORd,IOWr,CfgRd0,CfgWr0})->addr[63:32]==0; }
  constraint c_4dw   { (tlp_type inside {MRd64,MWr64})->addr[63:32]!=0; }
  constraint c_single{ (tlp_type inside {IORd,IOWr,CfgRd0,CfgWr0})->length==1; }
  constraint c_fbe   { first_be!=4'h0; }
  constraint c_lbe   { (length==1)->last_be==4'h0; }
  constraint c_ep    { ep==0; }

  function new(string name="pcie_tlp_seq_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("%-8s addr=0x%016h len=%0d tc=%0d tag=0x%02h be=%04b/%04b",
                     tlp_type.name(), addr, length, tc, tag, first_be, last_be);
  endfunction
  function bit is_write(); return tlp_type inside {MWr32,MWr64,IOWr,CfgWr0}; endfunction
endclass
`endif
