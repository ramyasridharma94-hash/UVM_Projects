`ifndef UCIE_SEQ_ITEM_SV
`define UCIE_SEQ_ITEM_SV

class ucie_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(ucie_seq_item)
    `uvm_field_int(flit_data, UVM_ALL_ON)
    `uvm_field_int(flit_type, UVM_ALL_ON)
  `uvm_object_utils_end

  // 256-bit UCIe flit payload
  rand bit [255:0] flit_data;
  // 0=data flit  1=null flit  (only data flits driven in these tests)
  rand bit [1:0]   flit_type;

  constraint data_flit_c { flit_type == 2'b00; }

  function new(string name = "ucie_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("type=%0d data[63:0]=0x%016h", flit_type, flit_data[63:0]);
  endfunction

endclass

`endif
