`ifndef BRIDGE_SPI_I2C_SCOREBOARD_SV
`define BRIDGE_SPI_I2C_SCOREBOARD_SV
class bridge_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(bridge_scoreboard)
  uvm_analysis_imp_master #(spi_seq_item, bridge_scoreboard) master_imp;
  uvm_analysis_imp_slave  #(i2c_seq_item, bridge_scoreboard) slave_imp;
  spi_seq_item master_q[$];
  i2c_seq_item slave_q[$];
  int          pass_count, fail_count;
  function new(string name = "bridge_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    master_imp = new("master_imp", this);
    slave_imp  = new("slave_imp",  this);
  endfunction
  function void write_master(spi_seq_item item); master_q.push_back(item); check_pair(); endfunction
  function void write_slave(i2c_seq_item item);  slave_q.push_back(item);  check_pair(); endfunction
  function void check_pair();
    if (master_q.size() == 0 || slave_q.size() == 0) return;
    begin
      spi_seq_item m = master_q.pop_front();
      i2c_seq_item s = slave_q.pop_front();
      // Check I2C address matches
      if (m.i2c_addr !== s.slave_addr) begin
        `uvm_error("SB", $sformatf("I2C ADDR MISMATCH: SPI=0x%02h I2C=0x%02h", m.i2c_addr, s.slave_addr))
        fail_count++;
      end else if ((m.op == SPI_BR_WRITE) && (m.data !== s.data)) begin
        `uvm_error("SB", $sformatf("DATA MISMATCH: SPI=0x%02h I2C=0x%02h", m.data, s.data))
        fail_count++;
      end else begin
        `uvm_info("SB", $sformatf("MATCH addr=0x%02h op=%s", m.i2c_addr, m.op.name()), UVM_HIGH)
        pass_count++;
      end
    end
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("SPI-I2C Bridge SB: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0) `uvm_error("SB", "TEST FAILED")
    else                `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction
endclass
`endif
