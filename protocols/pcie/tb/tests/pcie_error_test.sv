`ifndef PCIE_ERROR_TEST_SV
`define PCIE_ERROR_TEST_SV

// Error injection and AER test — correctable and uncorrectable errors
class pcie_error_test extends pcie_base_test;
  `uvm_component_utils(pcie_error_test)
  import pcie_pkg::*;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Signal scoreboard that errors are expected
    uvm_config_db #(bit)::set(this, "env.scoreboard", "expected_errors", 1);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_err_seq       err_seq;
    pcie_aer_sweep_seq sweep;

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "=== AER Error Injection Test ===", UVM_LOW)

    // Single error types
    foreach ({ERR_ECRC, ERR_BAD_TLP, ERR_POISONED_TLP,
              ERR_UNSUPPORTED_REQ, ERR_COMPLETER_ABORT}[i]) begin
      err_seq = pcie_err_seq::type_id::create($sformatf("err_%0d", i));
      err_seq.err_type = pcie_error_e'(i);
      err_seq.start(env.agent.sequencer);
      #50ns;
    end

    // Full AER sweep
    `uvm_info(get_type_name(), "Running full AER error sweep", UVM_LOW)
    sweep = pcie_aer_sweep_seq::type_id::create("aer_sweep");
    sweep.start(env.agent.sequencer);

    #200ns;
    phase.drop_objection(this);
  endtask

endclass : pcie_error_test

`endif
