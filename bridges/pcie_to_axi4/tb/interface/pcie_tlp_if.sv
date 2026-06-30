import pcie_pkg::*;
interface pcie_tlp_if (input logic clk, input logic rst_n);
  logic              req_valid;
  tlp_type_e         req_tlp_type;
  logic [63:0]       req_addr;
  logic [9:0]        req_length;
  logic [2:0]        req_tc;
  logic [1:0]        req_attr;
  logic [15:0]       req_req_id;
  logic [7:0]        req_tag;
  logic [3:0]        req_first_be, req_last_be;
  logic              req_ep;
  logic [63:0]       req_data_lo, req_data_hi;
  logic              req_ready;
  logic              cpl_valid;
  logic [63:0]       cpl_data;
  logic [7:0]        cpl_tag;
  logic [2:0]        cpl_status;

  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output req_valid, req_tlp_type, req_addr, req_length, req_tc, req_attr,
           req_req_id, req_tag, req_first_be, req_last_be, req_ep,
           req_data_lo, req_data_hi;
    input  req_ready, cpl_valid, cpl_data, cpl_tag, cpl_status;
  endclocking
  clocking monitor_cb @(posedge clk);
    default input #1;
    input req_valid, req_tlp_type, req_addr, req_length, req_tc, req_attr,
          req_req_id, req_tag, req_first_be, req_last_be, req_ep,
          req_data_lo, req_data_hi, req_ready;
    input cpl_valid, cpl_data, cpl_tag, cpl_status;
  endclocking
  modport driver_mp  (clocking driver_cb,  input clk, input rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);
endinterface
