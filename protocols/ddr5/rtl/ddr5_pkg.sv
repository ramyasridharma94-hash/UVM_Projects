// DDR5 / LPDDR5 Protocol Package
// Covers DDR5-4800 through DDR5-8400 and LPDDR5-6400/7500
package ddr5_pkg;

  // -----------------------------------------------------------------------
  // DDR5 Command Encodings (CA[13:0] bus)
  // -----------------------------------------------------------------------
  typedef enum logic [6:0] {
    CMD_ACT    = 7'b001_0000,   // Activate
    CMD_PRE    = 7'b000_1010,   // Precharge single bank
    CMD_PREA   = 7'b000_1011,   // Precharge all banks
    CMD_RD     = 7'b010_1000,   // Read
    CMD_RDA    = 7'b010_1001,   // Read with Auto-Precharge
    CMD_WR     = 7'b011_1000,   // Write
    CMD_WRA    = 7'b011_1001,   // Write with Auto-Precharge
    CMD_MRS    = 7'b100_0001,   // Mode Register Set
    CMD_MRR    = 7'b100_0010,   // Mode Register Read
    CMD_REF    = 7'b000_0001,   // Refresh all banks
    CMD_REFPB  = 7'b000_0010,   // Per-Bank Refresh
    CMD_REFSB  = 7'b000_0100,   // Same-Bank Refresh
    CMD_NOP    = 7'b000_0000,   // No Operation
    CMD_DES    = 7'b111_1111,   // Deselect
    CMD_PDE    = 7'b100_1000,   // Power-Down Entry
    CMD_PDX    = 7'b100_1001,   // Power-Down Exit
    CMD_SRE    = 7'b100_1010,   // Self-Refresh Entry
    CMD_SRX    = 7'b100_1011,   // Self-Refresh Exit
    CMD_ZQCAL  = 7'b101_0001,   // ZQ Calibration Start
    CMD_ZQLAT  = 7'b101_0010,   // ZQ Calibration Latch
    CMD_VrefCA = 7'b110_0001,   // VREF CA Training
    CMD_VrefDQ = 7'b110_0010,   // VREF DQ Training
    CMD_WL     = 7'b111_0001,   // Write Leveling Enable
    CMD_RLT    = 7'b111_0010,   // Read Latency Training
    CMD_WLT    = 7'b111_0011,   // Write Latency Training
    CMD_PARITY = 7'b111_1110    // Parity Error Test
  } ddr5_cmd_e;

  // -----------------------------------------------------------------------
  // Burst Length
  // -----------------------------------------------------------------------
  typedef enum logic [1:0] {
    BL8  = 2'b00,
    BC4  = 2'b01,   // Burst Chop 4
    BL16 = 2'b10
  } burst_len_e;

  // -----------------------------------------------------------------------
  // CAS Latency presets
  // -----------------------------------------------------------------------
  typedef enum logic [5:0] {
    CL20 = 6'd20, CL22 = 6'd22, CL24 = 6'd24, CL26 = 6'd26,
    CL28 = 6'd28, CL30 = 6'd30, CL32 = 6'd32, CL34 = 6'd34,
    CL36 = 6'd36, CL38 = 6'd38, CL40 = 6'd40
  } cas_latency_e;

  // -----------------------------------------------------------------------
  // Refresh Modes
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    REF_NORMAL    = 3'h0,   // Normal refresh (all-bank, tREFI=3.9µs)
    REF_FGR_2X    = 3'h1,   // Fine Granularity 2x (1.95µs)
    REF_FGR_4X    = 3'h2,   // Fine Granularity 4x
    REF_PBR       = 3'h3,   // Per-Bank Refresh
    REF_SBR       = 3'h4    // Same-Bank Refresh (LPDDR5)
  } refresh_mode_e;

  // -----------------------------------------------------------------------
  // Power State
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    PWR_NORMAL   = 3'h0,
    PWR_PD       = 3'h1,   // Power-Down
    PWR_SREF     = 3'h2,   // Self-Refresh
    PWR_DPD      = 3'h3,   // Deep Power-Down (LPDDR5)
    PWR_PASR     = 3'h4    // Partial Array Self-Refresh (LPDDR5)
  } power_state_e;

  // -----------------------------------------------------------------------
  // ECC Mode
  // -----------------------------------------------------------------------
  typedef enum logic [1:0] {
    ECC_OFF      = 2'h0,
    ECC_SEC_DED  = 2'h1,   // Single-bit correct, Double-bit detect
    ECC_SDDC     = 2'h2,   // Symbol-based DDC
    ECC_INLINE   = 2'h3    // Inline ECC
  } ecc_mode_e;

  // -----------------------------------------------------------------------
  // LPDDR5 vs DDR5 device type
  // -----------------------------------------------------------------------
  typedef enum logic {
    DDR5   = 1'b0,
    LPDDR5 = 1'b1
  } dram_type_e;

  // -----------------------------------------------------------------------
  // DDR5 Mode Register Map (MR0–MR37)
  // -----------------------------------------------------------------------
  typedef struct packed {
    logic [7:0]  mr0;   // BL, CAS Latency
    logic [7:0]  mr2;   // Write Leveling
    logic [7:0]  mr3;   // Gear-Down Mode, Power-Down Control
    logic [7:0]  mr4;   // Refresh Rate, DRAM Temperature
    logic [7:0]  mr5;   // CA ODT, CS ODT
    logic [7:0]  mr6;   // RTT_NOM_WR
    logic [7:0]  mr7;   // RTT_NOM_RD
    logic [7:0]  mr8;   // VREF DQ, Write Preamble
    logic [7:0]  mr10;  // ODT Write Timing
    logic [7:0]  mr11;  // ODT Read Timing
    logic [7:0]  mr13;  // DM/ECC/CA Parity
    logic [7:0]  mr15;  // ECC Mode, DFE
    logic [7:0]  mr17;  // ODT Driver Impedance
    logic [7:0]  mr24;  // tCCD_L Fine
    logic [7:0]  mr28;  // RFM (Refresh Management)
  } ddr5_mode_regs_t;

  // -----------------------------------------------------------------------
  // DDR5 Timing Parameters (in ns, normalized to clock cycles at runtime)
  // -----------------------------------------------------------------------
  typedef struct {
    int unsigned tCL;     // CAS Latency
    int unsigned tCWL;    // CAS Write Latency
    int unsigned tRCD;    // RAS to CAS Delay
    int unsigned tRP;     // Precharge Time
    int unsigned tRAS;    // Row Active Time
    int unsigned tRFC;    // Refresh Cycle Time (all-bank)
    int unsigned tRFC_PB; // Per-Bank Refresh Cycle Time
    int unsigned tREFI;   // Refresh Interval (cycles)
    int unsigned tWR;     // Write Recovery
    int unsigned tFAW;    // Four Activate Window
    int unsigned tRRD_S;  // RAS-to-RAS, different bank group
    int unsigned tRRD_L;  // RAS-to-RAS, same bank group
    int unsigned tCCD_S;  // CAS-to-CAS, different bank group
    int unsigned tCCD_L;  // CAS-to-CAS, same bank group
    int unsigned tWTR_S;  // Write-to-Read, different bank group
    int unsigned tWTR_L;  // Write-to-Read, same bank group
    int unsigned tRTP;    // Read-to-Precharge
    int unsigned tZQinit; // ZQ Calibration Init
    int unsigned tZQoper; // ZQ Calibration Operation
    int unsigned tXS;     // Self-Refresh Exit
    int unsigned tXP;     // Power-Down Exit
  } ddr5_timing_t;

  // DDR5-4800 timing preset (at tCK=0.416ns)
  function automatic ddr5_timing_t ddr5_4800_timing();
    ddr5_timing_t t;
    t.tCL=20; t.tCWL=14; t.tRCD=29; t.tRP=29; t.tRAS=52;
    t.tRFC=295/1; t.tRFC_PB=90; t.tREFI=9360;
    t.tWR=48; t.tFAW=16; t.tRRD_S=4; t.tRRD_L=6;
    t.tCCD_S=4; t.tCCD_L=8;
    t.tWTR_S=4; t.tWTR_L=12;
    t.tRTP=12; t.tZQinit=1024; t.tZQoper=512;
    t.tXS=300; t.tXP=8;
    return t;
  endfunction

  // DDR5-6400 timing preset
  function automatic ddr5_timing_t ddr5_6400_timing();
    ddr5_timing_t t;
    t.tCL=32; t.tCWL=24; t.tRCD=36; t.tRP=36; t.tRAS=64;
    t.tRFC=410; t.tRFC_PB=130; t.tREFI=12480;
    t.tWR=64; t.tFAW=20; t.tRRD_S=4; t.tRRD_L=8;
    t.tCCD_S=4; t.tCCD_L=12;
    t.tWTR_S=4; t.tWTR_L=16;
    t.tRTP=12; t.tZQinit=1024; t.tZQoper=512;
    t.tXS=400; t.tXP=10;
    return t;
  endfunction

  // -----------------------------------------------------------------------
  // DDR5 Bank / Address structure
  // -----------------------------------------------------------------------
  typedef struct packed {
    logic [2:0]  bank_group; // BG[2:0] — 8 bank groups in DDR5
    logic [1:0]  bank;       // BA[1:0] — 4 banks per group
    logic [16:0] row;        // R[16:0] — up to 128K rows
    logic [9:0]  col;        // C[9:0]  — 1K columns
  } ddr5_addr_t;

  // -----------------------------------------------------------------------
  // DFI (DRAM/PHY Interface) command packet
  // -----------------------------------------------------------------------
  typedef struct packed {
    logic [13:0] ca;          // Command/Address
    logic        cs_n;        // Chip Select
    logic        cke;         // Clock Enable
    logic        odt;         // On-Die Termination
    logic        reset_n;     // DRAM reset
    logic [1:0]  freq_ratio;  // 1:2 or 1:4
  } dfi_cmd_t;

  // -----------------------------------------------------------------------
  // Training mode
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    TRAIN_NONE      = 3'h0,
    TRAIN_WR_LEVEL  = 3'h1,   // Write Leveling
    TRAIN_RD_DQS    = 3'h2,   // Read DQS centering
    TRAIN_WR_DQ     = 3'h3,   // Write DQ training
    TRAIN_CA        = 3'h4,   // CA training
    TRAIN_VREF_DQ   = 3'h5,   // VREF DQ optimization
    TRAIN_VREF_CA   = 3'h6,   // VREF CA optimization
    TRAIN_ZQ        = 3'h7    // ZQ calibration
  } train_mode_e;

  // -----------------------------------------------------------------------
  // Error types
  // -----------------------------------------------------------------------
  typedef enum logic [3:0] {
    DDR5_ERR_NONE        = 4'h0,
    DDR5_ERR_PARITY      = 4'h1,  // CA parity error
    DDR5_ERR_ECC_SBE     = 4'h2,  // ECC single-bit error (corrected)
    DDR5_ERR_ECC_DBE     = 4'h3,  // ECC double-bit error (uncorrected)
    DDR5_ERR_WR_CRC      = 4'h4,  // Write CRC error
    DDR5_ERR_RD_CRC      = 4'h5,  // Read CRC error
    DDR5_ERR_TIMING_VIOL = 4'h6,  // Timing violation
    DDR5_ERR_ALERT       = 4'h7,  // DRAM ALERT_n asserted
    DDR5_ERR_REFRESH_TMO = 4'h8   // Refresh timeout
  } ddr5_error_e;

  // -----------------------------------------------------------------------
  // LPDDR5-specific: CA bus (6-bit, two-cycle encoding)
  // -----------------------------------------------------------------------
  typedef enum logic [5:0] {
    LP5_CMD_ACT    = 6'b00_0001,
    LP5_CMD_PRE    = 6'b00_0010,
    LP5_CMD_PREA   = 6'b00_0011,
    LP5_CMD_RD     = 6'b00_0100,
    LP5_CMD_WR     = 6'b00_0101,
    LP5_CMD_MPC    = 6'b00_0110,   // Multi-Purpose Command
    LP5_CMD_MRWC   = 6'b00_0111,   // Mode Register Write
    LP5_CMD_MRR    = 6'b00_1000,   // Mode Register Read
    LP5_CMD_REF    = 6'b01_0001,
    LP5_CMD_SREF   = 6'b01_0010,
    LP5_CMD_NOP    = 6'b00_0000
  } lpddr5_cmd_e;

  // -----------------------------------------------------------------------
  // Speed grade
  // -----------------------------------------------------------------------
  typedef enum logic [3:0] {
    DDR5_4800  = 4'h1,
    DDR5_5600  = 4'h2,
    DDR5_6400  = 4'h3,
    DDR5_7200  = 4'h4,
    DDR5_8400  = 4'h5,
    LPDDR5_6400= 4'h8,
    LPDDR5_7500= 4'h9
  } ddr5_speed_e;

  // -----------------------------------------------------------------------
  // Organization
  // -----------------------------------------------------------------------
  typedef enum logic [1:0] {
    ORG_X4  = 2'h0,
    ORG_X8  = 2'h1,
    ORG_X16 = 2'h2,
    ORG_X32 = 2'h3
  } dram_org_e;

endpackage : ddr5_pkg
