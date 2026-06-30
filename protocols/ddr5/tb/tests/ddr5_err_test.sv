`ifndef DDR5_ERR_TEST_SV
`define DDR5_ERR_TEST_SV
class ddr5_err_test extends ddr5_base_test;
  `uvm_component_utils(ddr5_err_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db #(bit)::set(this,"env.scoreboard","expected_errors",1);
  endfunction
  task run_phase(uvm_phase phase);
    ddr5_err_seq es;
    ddr5_error_e err_list[$] = '{
      DDR5_ERR_PARITY, DDR5_ERR_ECC_SBE, DDR5_ERR_ECC_DBE,
      DDR5_ERR_WR_CRC, DDR5_ERR_RD_CRC, DDR5_ERR_ALERT
    };
    phase.raise_objection(this);
    `uvm_info(get_type_name(),"=== DDR5 Error Injection Test ===",UVM_LOW)
    foreach (err_list[i]) begin
      es=ddr5_err_seq::type_id::create($sformatf("err_%0d",i));
      es.err_type=err_list[i]; es.start(env.agent.sequencer);
    end
    #500ns; phase.drop_objection(this);
  endtask
endclass
`endif
