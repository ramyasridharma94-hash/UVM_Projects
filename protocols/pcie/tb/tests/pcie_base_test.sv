`ifndef PCIE_BASE_TEST_SV
`define PCIE_BASE_TEST_SV

class pcie_base_test extends uvm_test;
  `uvm_component_utils(pcie_base_test)

  import pcie_pkg::*;

  pcie_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = pcie_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== PCIe Base Test ===", UVM_LOW)
    #100ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_base_test

`endif
