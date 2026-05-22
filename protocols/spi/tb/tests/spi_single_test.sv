`ifndef SPI_SINGLE_TEST_SV
`define SPI_SINGLE_TEST_SV
class spi_single_test extends spi_base_test;
  `uvm_component_utils(spi_single_test)
  function new(string name = "spi_single_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    spi_single_byte_seq seq;
    phase.raise_objection(this);
    seq = spi_single_byte_seq::type_id::create("seq");
    seq.num_txns = 8;
    seq.start(env.agent.seqr);
    #200;
    phase.drop_objection(this);
  endtask
endclass
`endif
