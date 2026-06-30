// DDR5 Address Mapper — converts AXI byte address to DDR5 {BG, BA, ROW, COL}
// Supports three interleaving policies to maximize bank-group parallelism:
//   POLICY_BG_FIRST:   {BG, BA, ROW, COL} → maximises BG switching (best BW)
//   POLICY_RANK_FIRST: {ROW, BG, BA, COL} → maximises row reuse
//   POLICY_COL_FIRST:  {COL, BG, BA, ROW} → sequential access pattern
// All policies align COL to burst length boundary (BL8=8B, BL16=16B)
import ddr5_pkg::*;

module ddr5_addr_mapper #(
  parameter int AXI_ADDR_W  = 34,
  parameter int ROW_BITS    = 17,
  parameter int COL_BITS    = 10,
  parameter int BG_BITS     = 3,
  parameter int BA_BITS     = 2,
  // Address bit positions (configurable for different DIMM organisations)
  // Default: 34-bit address for 16GB (8Gb×16 ×8 chips, x32 channel)
  //   [3:0]   = byte offset within BL8 (16B)
  //   [5:4]   = critical word (ignored for full burst)
  //   [15:6]  = COL[9:0]
  //   [18:16] = BG[2:0]
  //   [20:19] = BA[1:0]
  //   [33:21] = ROW[12:0]  (lower 13 of 17 row bits)
  parameter int COL_LSB     = 4,
  parameter int BG_LSB      = 14,
  parameter int BA_LSB      = 17,
  parameter int ROW_LSB     = 19,
  parameter int POLICY      = 0   // 0=BG_FIRST, 1=RANK_FIRST, 2=COL_FIRST
)(
  input  logic [AXI_ADDR_W-1:0]  axi_addr,
  input  burst_len_e              burst_len_cfg,
  // DDR5 decoded fields
  output logic [BG_BITS-1:0]     ddr5_bg,
  output logic [BA_BITS-1:0]     ddr5_ba,
  output logic [ROW_BITS-1:0]    ddr5_row,
  output logic [COL_BITS-1:0]    ddr5_col,
  // Byte address of first beat (for data alignment)
  output logic [AXI_ADDR_W-1:0]  aligned_addr
);

  // -----------------------------------------------------------------------
  // Burst-length aligned column address
  // BL8  → 4 bytes per beat × 8 beats = 32 bytes → COL[1:0] forced 0
  // BL16 → 4 bytes per beat × 16 beats = 64 bytes → COL[2:0] forced 0
  // -----------------------------------------------------------------------
  logic [COL_BITS-1:0] col_raw;
  logic [COL_BITS-1:0] col_aligned;
  logic [2:0]          col_mask_bits;

  always_comb begin
    case (burst_len_cfg)
      BL8:    col_mask_bits = 3'd2;  // 32B: mask lower 2 bits
      BL16:   col_mask_bits = 3'd3;  // 64B: mask lower 3 bits
      BC4:    col_mask_bits = 3'd1;  // 16B: mask lower 1 bit
      default:col_mask_bits = 3'd2;
    endcase
  end

  generate
    case (POLICY)
      // -------------------------------------------------------
      // POLICY 0: BG-first interleaving (best bandwidth)
      // Addr: [ ROW | BA | BG | COL | byte-offset ]
      // -------------------------------------------------------
      0: begin : gen_bg_first
        always_comb begin
          col_raw     = axi_addr[COL_LSB + COL_BITS - 1 : COL_LSB];
          col_aligned = col_raw & ~((COL_BITS'(1) << col_mask_bits) - 1);
          ddr5_col    = col_aligned;
          ddr5_bg     = axi_addr[BG_LSB  + BG_BITS  - 1 : BG_LSB];
          ddr5_ba     = axi_addr[BA_LSB  + BA_BITS  - 1 : BA_LSB];
          ddr5_row    = {{(ROW_BITS-(AXI_ADDR_W-ROW_LSB)){1'b0}},
                         axi_addr[AXI_ADDR_W-1 : ROW_LSB]};
          aligned_addr= {axi_addr[AXI_ADDR_W-1 : COL_LSB],
                         {COL_LSB{1'b0}}};
        end
      end

      // -------------------------------------------------------
      // POLICY 1: Rank-first (same-row streaming)
      // Addr: [ BG | BA | ROW | COL | byte-offset ]
      // -------------------------------------------------------
      1: begin : gen_rank_first
        always_comb begin
          col_raw     = axi_addr[COL_LSB + COL_BITS - 1 : COL_LSB];
          col_aligned = col_raw & ~((COL_BITS'(1) << col_mask_bits) - 1);
          ddr5_col    = col_aligned;
          ddr5_row    = axi_addr[COL_LSB + COL_BITS + ROW_BITS - 1 :
                                  COL_LSB + COL_BITS];
          ddr5_ba     = axi_addr[COL_LSB + COL_BITS + ROW_BITS + BA_BITS - 1 :
                                  COL_LSB + COL_BITS + ROW_BITS];
          ddr5_bg     = axi_addr[AXI_ADDR_W-1 :
                                  COL_LSB + COL_BITS + ROW_BITS + BA_BITS];
          aligned_addr= {axi_addr[AXI_ADDR_W-1 : COL_LSB], {COL_LSB{1'b0}}};
        end
      end

      // -------------------------------------------------------
      // POLICY 2: Column-first (sequential access)
      // Addr: [ BG | BA | ROW | COL | byte-offset ]  (same field order)
      // -------------------------------------------------------
      default: begin : gen_col_first
        always_comb begin
          col_raw     = axi_addr[COL_LSB + COL_BITS - 1 : COL_LSB];
          col_aligned = col_raw & ~((COL_BITS'(1) << col_mask_bits) - 1);
          ddr5_col    = col_aligned;
          ddr5_bg     = axi_addr[BG_LSB  + BG_BITS  - 1 : BG_LSB];
          ddr5_ba     = axi_addr[BA_LSB  + BA_BITS  - 1 : BA_LSB];
          ddr5_row    = {{(ROW_BITS - (AXI_ADDR_W - ROW_LSB)){1'b0}},
                         axi_addr[AXI_ADDR_W-1 : ROW_LSB]};
          aligned_addr= axi_addr;
        end
      end
    endcase
  endgenerate

endmodule : ddr5_addr_mapper
