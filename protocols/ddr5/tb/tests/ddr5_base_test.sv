`ifndef DDR5_BASE_TEST_SV
`define DDR5_BASE_TEST_SV
class ddr5_base_test extends uvm_test;
  `uvm_component_utils(ddr5_base_test)
  import ddr5_pkg::*;
  ddr5_env env;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = ddr5_env::type_id::create("env", this);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== DDR5/LPDDR5 Base Test ===", UVM_LOW)
    #1000ns; phase.drop_objection(this);
  endtask
endclass
`endif
