`ifndef SPI_MULTI_TEST_SV
`define SPI_MULTI_TEST_SV
class spi_multi_test extends spi_base_test;
  `uvm_component_utils(spi_multi_test)
  function new(string name = "spi_multi_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    spi_multi_byte_seq seq;
    phase.raise_objection(this);
    seq = spi_multi_byte_seq::type_id::create("seq");
    seq.num_txns = 4;
    seq.start(env.agent.seqr);
    #400;
    phase.drop_objection(this);
  endtask
endclass
`endif
