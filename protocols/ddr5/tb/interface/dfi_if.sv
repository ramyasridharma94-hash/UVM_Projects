// DFI (DRAM/PHY Interface) — standardized controller↔PHY interface
import ddr5_pkg::*;

interface dfi_if (input logic dfi_clk, input logic rst_n);

  // ---- Control signals (controller → PHY) ----
  logic [13:0]  dfi_address;       // Command/address
  logic [1:0]   dfi_bank;
  logic [2:0]   dfi_bank_group;
  logic         dfi_cas_n;
  logic         dfi_ras_n;
  logic         dfi_we_n;
  logic         dfi_cs_n;
  logic         dfi_cke;
  logic         dfi_odt;
  logic         dfi_reset_n;
  logic [1:0]   dfi_freq_ratio;    // 1:2 or 1:4 freq ratio

  // ---- Write data path ----
  logic [63:0]  dfi_wrdata;        // 64b per phase
  logic [7:0]   dfi_wrdata_mask;
  logic         dfi_wrdata_en;
  logic [4:0]   dfi_wrdata_cs_n;

  // ---- Read data path ----
  logic [63:0]  dfi_rddata;
  logic         dfi_rddata_valid;
  logic         dfi_rddata_en;
  logic [4:0]   dfi_rddata_cs_n;

  // ---- Timing control ----
  logic [4:0]   dfi_t_rddata_en;   // tphy_rdlat
  logic [4:0]   dfi_t_wrdata;      // write data timing
  logic [4:0]   dfi_t_ctrl_delay;  // ctrl path delay

  // ---- Training / Update ----
  logic         dfi_init_start;
  logic         dfi_init_complete;
  logic         dfi_phyupd_req;
  logic         dfi_phyupd_ack;
  logic         dfi_ctrlupd_req;
  logic         dfi_ctrlupd_ack;

  // ---- PHY status ----
  logic         dfi_alert_n;
  logic         dfi_error;
  logic [3:0]   dfi_error_info;

  // ---- Low-power ----
  logic         dfi_lp_req;
  logic         dfi_lp_ack;
  logic [3:0]   dfi_lp_wakeup;

  clocking ctrl_cb @(posedge dfi_clk);
    default input #1 output #1;
    output dfi_address, dfi_bank, dfi_bank_group, dfi_cs_n;
    output dfi_cas_n, dfi_ras_n, dfi_we_n, dfi_cke, dfi_odt, dfi_reset_n;
    output dfi_wrdata, dfi_wrdata_mask, dfi_wrdata_en;
    output dfi_rddata_en, dfi_t_rddata_en, dfi_t_wrdata, dfi_t_ctrl_delay;
    output dfi_init_start, dfi_phyupd_ack, dfi_ctrlupd_req;
    output dfi_lp_req, dfi_lp_wakeup;
    input  dfi_rddata, dfi_rddata_valid;
    input  dfi_init_complete, dfi_phyupd_req, dfi_ctrlupd_ack;
    input  dfi_alert_n, dfi_error, dfi_error_info;
    input  dfi_lp_ack;
  endclocking

  clocking monitor_cb @(posedge dfi_clk);
    default input #1;
    input dfi_address, dfi_bank, dfi_bank_group, dfi_cs_n;
    input dfi_cke, dfi_odt, dfi_reset_n;
    input dfi_wrdata, dfi_wrdata_mask, dfi_wrdata_en;
    input dfi_rddata, dfi_rddata_valid, dfi_rddata_en;
    input dfi_init_start, dfi_init_complete;
    input dfi_phyupd_req, dfi_phyupd_ack;
    input dfi_alert_n, dfi_error, dfi_error_info;
    input dfi_lp_req, dfi_lp_ack;
  endclocking

  modport ctrl_mp    (clocking ctrl_cb,    input dfi_clk, rst_n);
  modport monitor_mp (clocking monitor_cb, input dfi_clk, rst_n);

endinterface : dfi_if
