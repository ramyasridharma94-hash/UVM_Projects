`ifndef AXI4_LITE_BASE_TEST_SV
`define AXI4_LITE_BASE_TEST_SV
class axi4_lite_base_test extends uvm_test;
  `uvm_component_utils(axi4_lite_base_test)
  axi4_lite_env env;
  function new(string name = "axi4_lite_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi4_lite_env::type_id::create("env", this);
  endfunction
  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #100;
    phase.drop_objection(this);
  endtask
endclass
`endif
