`ifndef I2C_COVERAGE_SV
`define I2C_COVERAGE_SV
class i2c_coverage extends uvm_subscriber #(i2c_seq_item);
  `uvm_component_utils(i2c_coverage)
  i2c_seq_item item;
  covergroup i2c_cg;
    cp_op:   coverpoint item.op   { bins wr={I2C_WRITE}; bins rd={I2C_READ}; }
    cp_nack: coverpoint item.nack { bins ack={0}; bins nack={1}; }
    cp_len:  coverpoint item.data.size() { bins one={1}; bins multi[]={[2:4]}; }
    cx_op_len: cross cp_op, cp_len;
  endgroup
  function new(string name = "i2c_coverage", uvm_component parent = null);
    super.new(name, parent);
    i2c_cg = new();
  endfunction
  function void write(i2c_seq_item t); item = t; i2c_cg.sample(); endfunction
endclass
`endif
