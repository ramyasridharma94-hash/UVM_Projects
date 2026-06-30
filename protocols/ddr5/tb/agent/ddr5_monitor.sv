`ifndef DDR5_MONITOR_SV
`define DDR5_MONITOR_SV

class ddr5_monitor extends uvm_monitor;
  `uvm_component_utils(ddr5_monitor)
  import ddr5_pkg::*;

  virtual ddr5_if.monitor_mp vif;

  uvm_analysis_port #(ddr5_seq_item) ap_cmd;    // Command transactions
  uvm_analysis_port #(ddr5_seq_item) ap_rd;     // Read completions
  uvm_analysis_port #(ddr5_seq_item) ap_wr;     // Write transactions
  uvm_analysis_port #(ddr5_seq_item) ap_ref;    // Refresh events
  uvm_analysis_port #(ddr5_seq_item) ap_err;    // Error events

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_cmd = new("ap_cmd", this); ap_rd  = new("ap_rd",  this);
    ap_wr  = new("ap_wr",  this); ap_ref = new("ap_ref", this);
    ap_err = new("ap_err", this);
    if (!uvm_config_db #(virtual ddr5_if)::get(this, "", "ddr5_vif", vif))
      `uvm_fatal("NOVIF", "ddr5_monitor: ddr5_vif not found")
  endfunction

  task run_phase(uvm_phase phase);
    fork
      monitor_ca();
      monitor_data();
      monitor_alert();
    join
  endtask

  // -----------------------------------------------------------------------
  // Monitor CA bus — decode DDR5 commands
  // -----------------------------------------------------------------------
  task monitor_ca();
    forever begin
      @(vif.monitor_cb);
      if (!vif.monitor_cb.cs_n) begin
        ddr5_seq_item it = ddr5_seq_item::type_id::create("mon_cmd");
        logic [13:0] ca0 = vif.monitor_cb.ca;
        // Decode cmd from CA[6:0]
        it.cmd  = ddr5_cmd_e'(ca0[6:0]);
        it.bg   = ca0[9:7];
        it.bank = ca0[11:10];
        @(vif.monitor_cb);
        // Second CA cycle for ACT/WR/RD
        case (it.cmd)
          CMD_ACT: begin
            it.row = {ca0[12:10], vif.monitor_cb.ca[13:0]};
            `uvm_info("MON_CA", $sformatf("ACT BG%0d BA%0d row=0x%05h", it.bg, it.bank, it.row), UVM_HIGH)
          end
          CMD_WR, CMD_WRA: begin
            it.col = {ca0[9:2], 2'b0};
            `uvm_info("MON_CA", $sformatf("WR BG%0d BA%0d col=0x%03h", it.bg, it.bank, it.col), UVM_HIGH)
          end
          CMD_RD, CMD_RDA: begin
            it.col = {ca0[9:2], 2'b0};
            `uvm_info("MON_CA", $sformatf("RD BG%0d BA%0d col=0x%03h", it.bg, it.bank, it.col), UVM_HIGH)
          end
          CMD_REF, CMD_REFPB: begin
            `uvm_info("MON_CA", $sformatf("REF%s", it.cmd==CMD_REFPB?"-PB":""), UVM_MEDIUM)
          end
          CMD_MRS: begin
            it.mr_addr = vif.monitor_cb.ca[7:0];
            `uvm_info("MON_CA", $sformatf("MRS MR%0d", it.mr_addr), UVM_MEDIUM)
          end
          CMD_PDE: `uvm_info("MON_CA", "Power-Down Entry", UVM_LOW)
          CMD_SRE: `uvm_info("MON_CA", "Self-Refresh Entry", UVM_LOW)
          default: ;
        endcase
        ap_cmd.write(it);
        if (it.cmd inside {CMD_REF, CMD_REFPB, CMD_REFSB}) ap_ref.write(it);
        if (it.is_write()) ap_wr.write(it);
      end
    end
  endtask

  // -----------------------------------------------------------------------
  // Monitor DQ data bus — capture read data
  // -----------------------------------------------------------------------
  task monitor_data();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.dq_oe == 0 && vif.monitor_cb.dqs_t[0]) begin
        ddr5_seq_item it = ddr5_seq_item::type_id::create("mon_rd");
        it.cmd = CMD_RD;
        for (int beat = 0; beat < 8; beat++) begin
          it.wdata[beat*32 +: 32] = vif.monitor_cb.dq_in;
          @(vif.monitor_cb);
        end
        ap_rd.write(it);
        `uvm_info("MON_DQ", $sformatf("RD data[63:0]=0x%016h", it.wdata[63:0]), UVM_HIGH)
      end
    end
  endtask

  // -----------------------------------------------------------------------
  // Monitor ALERT_n
  // -----------------------------------------------------------------------
  task monitor_alert();
    forever begin
      @(negedge vif.monitor_cb.alert_n);
      ddr5_seq_item it = ddr5_seq_item::type_id::create("mon_err");
      it.inject_err = DDR5_ERR_ALERT;
      ap_err.write(it);
      `uvm_warning("MON_ALERT", "DRAM ALERT_n asserted!")
    end
  endtask

endclass : ddr5_monitor

`endif
