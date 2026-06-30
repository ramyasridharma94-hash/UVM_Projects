`ifndef DDR5_DRIVER_SV
`define DDR5_DRIVER_SV

class ddr5_driver extends uvm_driver #(ddr5_seq_item);
  `uvm_component_utils(ddr5_driver)
  import ddr5_pkg::*;

  virtual ddr5_if.driver_mp vif;

  // Track open rows per BG.Bank
  logic [16:0] open_rows [0:31];
  bit          row_open   [0:31];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ddr5_if)::get(this, "", "ddr5_vif", vif))
      `uvm_fatal("NOVIF", "ddr5_driver: ddr5_vif not found")
  endfunction

  task run_phase(uvm_phase phase);
    ddr5_seq_item item;
    // Initialize bus
    vif.driver_cb.ca     <= '0;
    vif.driver_cb.cs_n   <= 1;
    vif.driver_cb.cke    <= 1;
    vif.driver_cb.odt    <= 0;
    vif.driver_cb.dq_oe  <= 0;
    vif.driver_cb.dq_out <= '0;
    // Wait for init done (signaled via config_db in TB)
    repeat (300) @(vif.driver_cb);

    forever begin
      seq_item_port.get_next_item(item);
      drive_cmd(item);
      seq_item_port.item_done();
    end
  endtask

  task drive_cmd(ddr5_seq_item item);
    int bk_idx = int'(item.bg)*4 + int'(item.bank);

    // Issue command on CA bus
    @(vif.driver_cb);
    vif.driver_cb.cs_n <= 0;
    vif.driver_cb.par  <= ^{item.cmd[6:0]};  // odd parity

    case (item.cmd)
      CMD_ACT: begin
        // ACT: CA[13:0] = {row[16:14], bg[2:0], bank[1:0], row[13:0]}
        vif.driver_cb.ca  <= {item.row[16:14], item.bg, item.bank, item.row[13:8]};
        @(vif.driver_cb);
        vif.driver_cb.ca  <= {item.row[7:0], 6'h0};
        row_open[bk_idx]   = 1;
        open_rows[bk_idx]  = item.row;
        `uvm_info("DRV", $sformatf("ACT BG%0d BA%0d row=0x%05h", item.bg, item.bank, item.row), UVM_HIGH)
      end

      CMD_WR, CMD_WRA: begin
        vif.driver_cb.ca <= {item.col[9:2], 6'h0};
        // Write data (8 beats)
        @(vif.driver_cb);
        vif.driver_cb.dq_oe <= 1;
        for (int beat = 0; beat < 8; beat++) begin
          vif.driver_cb.dq_out <= item.wdata[beat*32 +: 32];
          @(vif.driver_cb);
        end
        vif.driver_cb.dq_oe <= 0;
        `uvm_info("DRV", $sformatf("WR BG%0d BA%0d col=0x%03h", item.bg, item.bank, item.col), UVM_HIGH)
        if (item.auto_precharge) row_open[bk_idx] = 0;
      end

      CMD_RD, CMD_RDA: begin
        vif.driver_cb.ca <= {item.col[9:2], 6'h0};
        `uvm_info("DRV", $sformatf("RD BG%0d BA%0d col=0x%03h", item.bg, item.bank, item.col), UVM_HIGH)
        if (item.auto_precharge) row_open[bk_idx] = 0;
      end

      CMD_PRE: begin
        vif.driver_cb.ca <= 14'h0;
        row_open[bk_idx]  = 0;
      end

      CMD_PREA: begin
        vif.driver_cb.ca <= 14'h0400;  // AP bit set
        for (int i=0; i<32; i++) row_open[i] = 0;
      end

      CMD_REF: begin
        vif.driver_cb.ca <= 14'h0001;
        `uvm_info("DRV", "REF issued", UVM_HIGH)
      end

      CMD_REFPB: begin
        vif.driver_cb.ca <= {item.bg, item.bank, 9'h002};
        `uvm_info("DRV", $sformatf("REF-PB BG%0d BA%0d", item.bg, item.bank), UVM_HIGH)
      end

      CMD_MRS: begin
        vif.driver_cb.ca <= {item.mr_addr, 6'h0};
        @(vif.driver_cb);
        vif.driver_cb.ca <= {6'h0, item.mr_data};
        `uvm_info("DRV", $sformatf("MRS MR%0d = 0x%02h", item.mr_addr, item.mr_data), UVM_LOW)
      end

      CMD_PDE: begin
        vif.driver_cb.cke <= 0;
        `uvm_info("DRV", "Power-Down Entry", UVM_LOW)
      end

      CMD_PDX: begin
        vif.driver_cb.cke <= 1;
        repeat (8) @(vif.driver_cb);
        `uvm_info("DRV", "Power-Down Exit", UVM_LOW)
      end

      CMD_SRE: begin
        vif.driver_cb.cke <= 0;
        `uvm_info("DRV", "Self-Refresh Entry", UVM_LOW)
      end

      CMD_SRX: begin
        vif.driver_cb.cke <= 1;
        repeat (16) @(vif.driver_cb);
        `uvm_info("DRV", "Self-Refresh Exit", UVM_LOW)
      end

      CMD_ZQCAL: begin
        vif.driver_cb.ca <= 14'h0100;
        repeat (64) @(vif.driver_cb);  // tZQoper
        `uvm_info("DRV", "ZQCAL complete", UVM_LOW)
      end

      CMD_NOP: ; // nothing

      default: `uvm_warning("DRV", $sformatf("Unhandled cmd: %s", item.cmd.name()))
    endcase

    @(vif.driver_cb);
    vif.driver_cb.cs_n <= 1;
    `uvm_info("DRV", item.convert2string(), UVM_HIGH)
  endtask

endclass : ddr5_driver

`endif
