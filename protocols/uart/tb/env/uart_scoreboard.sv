`ifndef UART_SCOREBOARD_SV
`define UART_SCOREBOARD_SV

class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)

  uvm_analysis_imp #(uart_seq_item, uart_scoreboard) analysis_export;

  // Queue of expected bytes (sent by driver)
  bit [7:0] exp_q[$];
  int       pass_count, fail_count;

  function new(string name = "uart_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // Called by monitor when RX byte captured
  function void write(uart_seq_item item);
    if (exp_q.size() == 0) begin
      `uvm_error("SB", $sformatf("Unexpected RX byte=0x%02h, no expected byte", item.data))
      fail_count++;
    end else begin
      bit [7:0] exp = exp_q.pop_front();
      if (item.data !== exp) begin
        `uvm_error("SB", $sformatf("MISMATCH exp=0x%02h got=0x%02h", exp, item.data))
        fail_count++;
      end else begin
        `uvm_info("SB", $sformatf("MATCH data=0x%02h", item.data), UVM_HIGH)
        pass_count++;
      end
    end
  endfunction

  function void add_expected(bit [7:0] data);
    exp_q.push_back(data);
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("UART SB: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0 || exp_q.size() > 0)
      `uvm_error("SB", $sformatf("TEST FAILED: %0d pending expected bytes", exp_q.size()))
    else
      `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction

endclass

`endif
