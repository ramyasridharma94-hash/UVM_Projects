// DDR5 / LPDDR5 DRAM Interface
// Models the physical DRAM bus: CK, CA, CS_n, DQ, DQS, DM, ALERT_n
import ddr5_pkg::*;

interface ddr5_if #(
  parameter int DQ_WIDTH  = 32,    // x16=16, x32=32
  parameter int DQS_WIDTH = DQ_WIDTH/8,
  parameter int CA_WIDTH  = 14     // DDR5=14, LPDDR5=6
)(
  input logic ck_t,     // Differential clock true
  input logic ck_c,     // Differential clock complement
  input logic rst_n
);

  // Command / Address
  logic [CA_WIDTH-1:0] ca;          // Command/Address bus
  logic                cs_n;        // Chip Select (active low)
  logic                cke;         // Clock Enable
  logic                odt;         // On-Die Termination
  logic                par;         // CA Parity (DDR5)

  // Data
  logic [DQ_WIDTH-1:0]  dq;         // Data bus (bidirectional, modeled as wire)
  logic [DQS_WIDTH-1:0] dqs_t;      // DQS differential true
  logic [DQS_WIDTH-1:0] dqs_c;      // DQS differential complement
  logic [DQS_WIDTH-1:0] dm_dbi;     // Data Mask / DBI

  // DRAM responses
  logic                alert_n;     // DRAM error alert (active low)

  // LPDDR5 extras
  logic                wck_t;       // Write Clock (LPDDR5, 4x ratio)
  logic                wck_c;
  logic                rdqs_t;      // Read DQS (LPDDR5 separate)
  logic                rdqs_c;

  // Controller-side driven signals (for driver use)
  logic [DQ_WIDTH-1:0]  dq_out;
  logic [DQ_WIDTH-1:0]  dq_in;
  logic                 dq_oe;      // Output enable

  // -----------------------------------------------------------------------
  // Clocking blocks
  // -----------------------------------------------------------------------
  clocking driver_cb @(posedge ck_t);
    default input #1 output #1;
    output ca, cs_n, cke, odt, par;
    output dq_out, dm_dbi, dq_oe;
    input  dq_in, alert_n, dqs_t, dqs_c;
  endclocking

  clocking monitor_cb @(posedge ck_t);
    default input #1;
    input ca, cs_n, cke, odt, par;
    input dq_out, dq_in, dm_dbi, dq_oe;
    input dqs_t, dqs_c, alert_n;
    input wck_t, wck_c;
  endclocking

  modport driver_mp  (clocking driver_cb,  input ck_t, ck_c, rst_n);
  modport monitor_mp (clocking monitor_cb, input ck_t, ck_c, rst_n);

  // -----------------------------------------------------------------------
  // SVA: CS_n must not toggle without CKE high
  property p_cke_before_cs;
    @(posedge ck_t) disable iff (!rst_n)
    (!cs_n) |-> cke;
  endproperty
  assert property (p_cke_before_cs)
    else $warning("DDR5_IF: CS_n asserted without CKE");

  // CA parity check: odd parity across CA[13:0]
  property p_ca_parity;
    @(posedge ck_t) disable iff (!rst_n)
    (!cs_n) |-> (^{ca, par} == 1'b1);
  endproperty
  assert property (p_ca_parity)
    else $warning("DDR5_IF: CA parity error detected");

  // Alert_n should not glitch during normal operation
  property p_alert_stable;
    @(posedge ck_t) disable iff (!rst_n)
    $fell(alert_n) |=> !alert_n [*4];
  endproperty
  assert property (p_alert_stable)
    else $warning("DDR5_IF: ALERT_n glitch detected");

endinterface : ddr5_if
