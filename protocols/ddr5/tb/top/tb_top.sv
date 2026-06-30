// DDR5/LPDDR5 UVM Testbench Top
`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import ddr5_pkg::*;
import ddr5_agent_pkg::*;

module tb_top;

  // -----------------------------------------------------------------------
  // Clock & Reset
  // -----------------------------------------------------------------------
  // DDR5-6400: tCK = 0.3125 ns → ~3.2 GHz system clock (use 2× = 1.5625ns half-period)
  logic clk, ck_t, ck_c, rst_n;
  initial clk = 0;
  always #2.5  clk = ~clk;     // 200 MHz system clock (DFI ref)
  always #0.78 ck_t = ~ck_t;   // DDR clock ~640 MHz (symbolic)
  initial ck_t = 0; assign ck_c = ~ck_t;

  initial begin
    rst_n = 0;
    repeat (20) @(negedge clk);
    rst_n = 1;
  end

  // -----------------------------------------------------------------------
  // Interfaces
  // -----------------------------------------------------------------------
  ddr5_if #(.DQ_WIDTH(32)) dram_if (.ck_t(ck_t), .ck_c(ck_c), .rst_n(rst_n));
  dfi_if                   dfi      (.dfi_clk(clk), .rst_n(rst_n));

  // Timing config (DDR5-4800)
  ddr5_timing_t     timing;
  ddr5_mode_regs_t  mode_regs;

  initial begin
    timing    = ddr5_4800_timing();
    mode_regs = '{
      mr0:  8'h14, mr2:  8'h00, mr3:  8'h01, mr4:  8'h00,
      mr5:  8'hCC, mr6:  8'h04, mr7:  8'h04, mr8:  8'h40,
      mr10: 8'h04, mr11: 8'h04, mr13: 8'h04, mr15: 8'h01,
      mr17: 8'h04, mr24: 8'h00, mr28: 8'h00
    };
  end

  // -----------------------------------------------------------------------
  // DUT — DDR5 Top
  // -----------------------------------------------------------------------
  logic              req_ready, rd_valid;
  logic [255:0]      rd_data;
  ddr5_error_e       err_type;
  logic              err_valid, init_done, dll_locked;
  power_state_e      pwr_state;

  ddr5_top #(.DQ_WIDTH(32)) dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .req_valid   (dfi.dfi_wrdata_en),       // proxy: TB drives via DFI
    .req_cmd     (CMD_NOP),
    .req_bg      ('0), .req_bank('0), .req_row('0), .req_col('0),
    .req_wdata   ('0), .req_wmask('0),
    .req_ready   (req_ready),
    .rd_valid    (rd_valid),
    .rd_data     (rd_data),
    .train_mode  (TRAIN_NONE),
    .train_done  (),
    .timing      (timing),
    .mode_regs   (mode_regs),
    .err_type    (err_type),
    .err_valid   (err_valid),
    .dram_ca     (dram_if.ca),
    .dram_cs_n   (dram_if.cs_n),
    .dram_cke    (dram_if.cke),
    .dram_odt    (dram_if.odt),
    .dram_reset_n(dram_if.driver_cb.odt),
    .dram_ck_t   (),
    .dram_ck_c   (),
    .dq_out      (dram_if.dq_out),
    .dq_in       (dram_if.dq_in),
    .dq_oe       (dram_if.dq_oe),
    .init_done   (init_done),
    .pwr_state   (pwr_state),
    .dll_locked  (dll_locked)
  );

  // Simple DRAM loopback: dq_in reflects dq_out after tCL cycles
  logic [31:0] dq_pipe [0:39];
  always_ff @(posedge ck_t) begin
    dq_pipe[0] <= dram_if.dq_out;
    for (int i=1; i<40; i++) dq_pipe[i] <= dq_pipe[i-1];
  end
  assign dram_if.dq_in = dq_pipe[20]; // tCL=20 loopback
  assign dram_if.alert_n = 1'b1;      // No alert by default

  // -----------------------------------------------------------------------
  // UVM kickoff
  // -----------------------------------------------------------------------
  initial begin
    uvm_config_db #(virtual ddr5_if)::set(null, "uvm_test_top.*", "ddr5_vif", dram_if);
    uvm_config_db #(virtual dfi_if)::set(null,  "uvm_test_top.*", "dfi_vif",  dfi);
    uvm_config_db #(ddr5_timing_t)::set(null,  "uvm_test_top.*", "timing",   timing);
    run_test();
  end

  initial begin $dumpfile("ddr5_tb.vcd"); $dumpvars(0, tb_top); end
  initial begin #100_000ns; `uvm_fatal("TB_TOP","Simulation timeout") end

endmodule : tb_top
