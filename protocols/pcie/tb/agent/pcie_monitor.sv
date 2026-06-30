`ifndef PCIE_MONITOR_SV
`define PCIE_MONITOR_SV

class pcie_monitor extends uvm_monitor;
  `uvm_component_utils(pcie_monitor)

  import pcie_pkg::*;

  virtual pcie_if.monitor_mp vif;

  // Analysis ports — one per TLP category + errors + LTSSM
  uvm_analysis_port #(pcie_tlp_seq_item) ap_posted;
  uvm_analysis_port #(pcie_tlp_seq_item) ap_non_posted;
  uvm_analysis_port #(pcie_tlp_seq_item) ap_completion;
  uvm_analysis_port #(pcie_tlp_seq_item) ap_req;      // all outgoing requests
  uvm_analysis_port #(pcie_tlp_seq_item) ap_cfg;
  uvm_analysis_port #(pcie_tlp_seq_item) ap_error;
  uvm_analysis_port #(pcie_tlp_seq_item) ap_pm;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_posted     = new("ap_posted",     this);
    ap_non_posted = new("ap_non_posted", this);
    ap_completion = new("ap_completion", this);
    ap_req        = new("ap_req",        this);
    ap_cfg        = new("ap_cfg",        this);
    ap_error      = new("ap_error",      this);
    ap_pm         = new("ap_pm",         this);
    if (!uvm_config_db #(virtual pcie_if)::get(this, "", "pcie_vif", vif))
      `uvm_fatal("NOVIF", "pcie_monitor: cannot get pcie_vif")
  endfunction

  task run_phase(uvm_phase phase);
    fork
      monitor_requests();
      monitor_posted();
      monitor_non_posted();
      monitor_completions();
      monitor_cfg();
      monitor_errors();
      monitor_ltssm();
      monitor_pm();
    join
  endtask

  // -----------------------------------------------------------------------
  // Monitor outgoing requests (req_valid & req_ready handshake)
  // -----------------------------------------------------------------------
  task monitor_requests();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.req_valid && vif.monitor_cb.req_ready) begin
        pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create("mon_req");
        item.tlp_type  = vif.monitor_cb.req_tlp_type;
        item.addr      = vif.monitor_cb.req_addr;
        item.length    = vif.monitor_cb.req_length;
        item.tc        = vif.monitor_cb.req_tc;
        item.attr      = vif.monitor_cb.req_attr;
        item.req_id    = vif.monitor_cb.req_req_id;
        item.tag       = {2'b0, vif.monitor_cb.req_tag};
        item.first_be  = vif.monitor_cb.req_first_be;
        item.last_be   = vif.monitor_cb.req_last_be;
        item.ep        = vif.monitor_cb.req_ep;
        item.ecrc_en   = vif.monitor_cb.req_ecrc_en;
        item.data_lo   = vif.monitor_cb.req_data_lo;
        item.data_hi   = vif.monitor_cb.req_data_hi;
        ap_req.write(item);
        `uvm_info("MON_REQ", item.convert2string(), UVM_HIGH)
      end
    end
  endtask

  // -----------------------------------------------------------------------
  // Monitor incoming posted TLPs (MWr, Msg)
  // -----------------------------------------------------------------------
  task monitor_posted();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.posted_valid) begin
        pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create("mon_post");
        item.tlp_type = vif.monitor_cb.posted_type;
        item.addr     = vif.monitor_cb.posted_addr;
        item.length   = vif.monitor_cb.posted_length;
        item.data_lo  = vif.monitor_cb.posted_data;
        item.tc       = vif.monitor_cb.posted_tc;
        item.ep       = vif.monitor_cb.posted_ep;
        ap_posted.write(item);
        `uvm_info("MON_POST", item.convert2string(), UVM_MEDIUM)
      end
    end
  endtask

  // -----------------------------------------------------------------------
  // Monitor incoming non-posted TLPs (MRd, IO, Cfg, AtomicOp)
  // -----------------------------------------------------------------------
  task monitor_non_posted();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.np_valid) begin
        pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create("mon_np");
        item.tlp_type  = vif.monitor_cb.np_type;
        item.addr      = vif.monitor_cb.np_addr;
        item.length    = vif.monitor_cb.np_length;
        item.req_id    = vif.monitor_cb.np_req_id;
        item.tag       = {2'b0, vif.monitor_cb.np_tag};
        item.first_be  = vif.monitor_cb.np_first_be;
        item.last_be   = vif.monitor_cb.np_last_be;
        item.tc        = vif.monitor_cb.np_tc;
        ap_non_posted.write(item);
        `uvm_info("MON_NP", item.convert2string(), UVM_HIGH)
      end
    end
  endtask

  // -----------------------------------------------------------------------
  // Monitor completions
  // -----------------------------------------------------------------------
  task monitor_completions();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.cpl_valid) begin
        pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create("mon_cpl");
        item.tlp_type    = vif.monitor_cb.cpl_type;
        item.cpl_status  = vif.monitor_cb.cpl_status;
        item.cpl_req_id  = vif.monitor_cb.cpl_req_id;
        item.cpl_tag     = vif.monitor_cb.cpl_tag;
        item.cpl_byte_cnt= vif.monitor_cb.cpl_byte_cnt;
        item.data_lo     = vif.monitor_cb.cpl_data;
        ap_completion.write(item);
        `uvm_info("MON_CPL", item.convert2string(), UVM_MEDIUM)
      end
    end
  endtask

  // -----------------------------------------------------------------------
  // Monitor config space accesses
  // -----------------------------------------------------------------------
  task monitor_cfg();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.cfg_rd_valid || vif.monitor_cb.cfg_wr_valid) begin
        pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create("mon_cfg");
        item.tlp_type = vif.monitor_cb.cfg_rd_valid ? CfgRd0 : CfgWr0;
        item.addr     = {52'h0, vif.monitor_cb.cfg_reg_num};
        item.req_id   = vif.monitor_cb.cfg_req_id_out;
        item.tag      = {2'b0, vif.monitor_cb.cfg_tag_out};
        item.data_lo  = {32'h0, vif.monitor_cb.cfg_wr_data};
        item.first_be = vif.monitor_cb.cfg_be;
        ap_cfg.write(item);
        `uvm_info("MON_CFG", $sformatf("CFG_%s reg=0x%03h data=0x%08h",
                  vif.monitor_cb.cfg_rd_valid ? "RD" : "WR",
                  vif.monitor_cb.cfg_reg_num,
                  vif.monitor_cb.cfg_wr_data), UVM_MEDIUM)
      end
    end
  endtask

  // -----------------------------------------------------------------------
  // Monitor AER errors
  // -----------------------------------------------------------------------
  task monitor_errors();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.aer_error_valid) begin
        pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create("mon_err");
        item.inject_err = vif.monitor_cb.aer_error;
        ap_error.write(item);
        `uvm_warning("MON_AER", $sformatf("AER error detected: %s",
                     vif.monitor_cb.aer_error.name()))
      end
    end
  endtask

  // -----------------------------------------------------------------------
  // Monitor LTSSM state transitions
  // -----------------------------------------------------------------------
  task monitor_ltssm();
    ltssm_state_e prev_state = LTSSM_DETECT_QUIET;
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.ltssm_state !== prev_state) begin
        `uvm_info("MON_LTSSM", $sformatf("LTSSM: %s → %s  link_up=%0b  speed=%s  width=x%0d",
                  prev_state.name(), vif.monitor_cb.ltssm_state.name(),
                  vif.monitor_cb.link_up,
                  vif.monitor_cb.negotiated_speed.name(),
                  vif.monitor_cb.negotiated_width), UVM_LOW)
        prev_state = vif.monitor_cb.ltssm_state;
      end
    end
  endtask

  // -----------------------------------------------------------------------
  // Monitor power management
  // -----------------------------------------------------------------------
  task monitor_pm();
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.pm_enter_l1_req) begin
        pcie_tlp_seq_item item = pcie_tlp_seq_item::type_id::create("mon_pm");
        item.tlp_type = Msg;
        ap_pm.write(item);
        `uvm_info("MON_PM", "PM: Enter L1 requested", UVM_LOW)
      end
      if (vif.monitor_cb.pm_ack)
        `uvm_info("MON_PM", "PM: ACK received", UVM_LOW)
    end
  endtask

endclass : pcie_monitor

`endif
