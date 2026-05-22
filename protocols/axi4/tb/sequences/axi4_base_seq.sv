`ifndef AXI4_BASE_SEQ_SV
`define AXI4_BASE_SEQ_SV

class axi4_base_seq extends uvm_sequence #(axi4_seq_item);
  `uvm_object_utils(axi4_base_seq)

  function new(string name = "axi4_base_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info("SEQ", "axi4_base_seq: no transactions", UVM_MEDIUM)
  endtask

endclass

`endif
