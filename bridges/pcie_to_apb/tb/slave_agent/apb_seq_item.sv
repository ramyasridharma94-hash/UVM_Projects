`ifndef APB_SEQ_ITEM_SV
`define APB_SEQ_ITEM_SV
class apb_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(wdata,  UVM_ALL_ON)
    `uvm_field_int(rdata,  UVM_ALL_ON)
    `uvm_field_int(strb,   UVM_ALL_ON)
    `uvm_field_int(prot,   UVM_ALL_ON)
    `uvm_field_int(write,  UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
  `uvm_object_utils_end

  logic [31:0] addr;
  logic [31:0] wdata;
  logic [31:0] rdata;
  logic [3:0]  strb;
  logic [2:0]  prot;
  logic        write;
  logic        slverr;

  function new(string name = "apb_seq_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("%s addr=0x%08h data=0x%08h strb=%04b slverr=%0b",
                     write ? "WR" : "RD", addr, write ? wdata : rdata, strb, slverr);
  endfunction
endclass
`endif
