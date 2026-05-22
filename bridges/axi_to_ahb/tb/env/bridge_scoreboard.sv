`ifndef BRIDGE_AXI_AHB_SCOREBOARD_SV
`define BRIDGE_AXI_AHB_SCOREBOARD_SV
class bridge_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(bridge_scoreboard)
  uvm_analysis_imp_master #(axi_lite_seq_item, bridge_scoreboard) master_imp;
  uvm_analysis_imp_slave  #(ahb_seq_item,      bridge_scoreboard) slave_imp;
  axi_lite_seq_item master_q[$];
  ahb_seq_item      slave_q[$];
  int               pass_count, fail_count;
  function new(string name = "bridge_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    master_imp = new("master_imp", this);
    slave_imp  = new("slave_imp",  this);
  endfunction
  function void write_master(axi_lite_seq_item item); master_q.push_back(item); check_pair(); endfunction
  function void write_slave(ahb_seq_item item);       slave_q.push_back(item);  check_pair(); endfunction
  function void check_pair();
    if (master_q.size() == 0 || slave_q.size() == 0) return;
    begin
      axi_lite_seq_item m = master_q.pop_front();
      ahb_seq_item      s = slave_q.pop_front();
      if (m.addr !== s.addr) begin
        `uvm_error("SB", $sformatf("ADDR MISMATCH: AXI=0x%08h AHB=0x%08h", m.addr, s.addr))
        fail_count++;
      end else if ((m.op == AXIL_WRITE) && (m.data !== s.data)) begin
        `uvm_error("SB", $sformatf("DATA MISMATCH: AXI=0x%08h AHB=0x%08h", m.data, s.data))
        fail_count++;
      end else begin
        `uvm_info("SB", $sformatf("MATCH addr=0x%08h op=%s", m.addr, m.op.name()), UVM_HIGH)
        pass_count++;
      end
    end
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("AXI-AHB Bridge SB: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0) `uvm_error("SB", "TEST FAILED")
    else                `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction
endclass
`endif
