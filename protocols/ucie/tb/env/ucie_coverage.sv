`ifndef UCIE_COVERAGE_SV
`define UCIE_COVERAGE_SV

class ucie_coverage extends uvm_subscriber #(ucie_seq_item);
  `uvm_component_utils(ucie_coverage)

  ucie_seq_item item;

  covergroup ucie_cg;
    // Cover data patterns in the lower 32 bits (representative of 256-bit flit)
    cp_data_lo: coverpoint item.flit_data[31:0] {
      bins all_zeros = {32'h0000_0000};
      bins all_ones  = {32'hFFFF_FFFF};
      bins low_byte  = {[32'h0000_0001 : 32'h0000_00FF]};
      bins mid_range = {[32'h0000_0100 : 32'hFFFE_FFFE]};
      bins other[]   = default;
    }
    // Cover upper 32 bits independently
    cp_data_hi: coverpoint item.flit_data[255:224] {
      bins all_zeros = {32'h0000_0000};
      bins all_ones  = {32'hFFFF_FFFF};
      bins non_zero  = {[32'h0000_0001 : 32'hFFFF_FFFE]};
    }
    // Cover flit type (data vs null)
    cp_type: coverpoint item.flit_type {
      bins data_flit = {2'b00};
      bins null_flit = {2'b01};
    }
  endgroup

  function new(string name = "ucie_coverage", uvm_component parent = null);
    super.new(name, parent);
    ucie_cg = new();
  endfunction

  function void write(ucie_seq_item t);
    item = t;
    ucie_cg.sample();
  endfunction

endclass

`endif
