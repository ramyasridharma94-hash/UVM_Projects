`ifndef UCIE_BASE_TEST_SV
`define UCIE_BASE_TEST_SV

class ucie_base_test extends uvm_test;
  `uvm_component_utils(ucie_base_test)

  ucie_env env;

  function new(string name = "ucie_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = ucie_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #100;
    phase.drop_objection(this);
  endtask

endclass

`endif
