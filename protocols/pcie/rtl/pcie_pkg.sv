// PCIe Protocol Package — type definitions shared across RTL and TB
package pcie_pkg;

  // -----------------------------------------------------------------------
  // TLP Type encoding (fmt[2:0] | type[4:0])
  // -----------------------------------------------------------------------
  typedef enum logic [7:0] {
    MRd32     = 8'b000_00000,  // Memory Read  (3DW hdr)
    MRd64     = 8'b001_00000,  // Memory Read  (4DW hdr)
    MRdLk32   = 8'b000_00001,  // Memory Read Lock (3DW)
    MRdLk64   = 8'b001_00001,  // Memory Read Lock (4DW)
    MWr32     = 8'b010_00000,  // Memory Write (3DW hdr + data)
    MWr64     = 8'b011_00000,  // Memory Write (4DW hdr + data)
    IORd      = 8'b000_00010,  // I/O Read
    IOWr      = 8'b010_00010,  // I/O Write
    CfgRd0    = 8'b000_00100,  // Config Read  Type 0
    CfgWr0    = 8'b010_00100,  // Config Write Type 0
    CfgRd1    = 8'b000_00101,  // Config Read  Type 1
    CfgWr1    = 8'b010_00101,  // Config Write Type 1
    Msg       = 8'b001_10000,  // Message (no data)
    MsgD      = 8'b011_10000,  // Message with Data
    Cpl       = 8'b000_01010,  // Completion (no data)
    CplD      = 8'b010_01010,  // Completion with Data
    CplLk     = 8'b000_01011,  // Completion Locked
    CplDLk    = 8'b010_01011,  // Completion Locked with Data
    FetchAdd32= 8'b010_01100,  // Fetch & Add (AtomicOp 3DW)
    FetchAdd64= 8'b011_01100,  // Fetch & Add (AtomicOp 4DW)
    Swap32    = 8'b010_01101,  // Unconditional Swap 3DW
    Swap64    = 8'b011_01101,  // Unconditional Swap 4DW
    CAS32     = 8'b010_01110,  // Compare-and-Swap 3DW
    CAS64     = 8'b011_01110,  // Compare-and-Swap 4DW
    LPrfx     = 8'b100_00000,  // Local TLP Prefix
    EPrfx     = 8'b100_00001   // End-to-End TLP Prefix
  } tlp_type_e;

  // -----------------------------------------------------------------------
  // DLLP Type encoding
  // -----------------------------------------------------------------------
  typedef enum logic [7:0] {
    DLLP_Ack        = 8'h00,
    DLLP_Nak        = 8'h10,
    DLLP_PM_EnterL1 = 8'h20,
    DLLP_PM_EnterL23= 8'h21,
    DLLP_PM_Req_Ack = 8'h22,
    DLLP_PM_TurnOff = 8'h23,
    DLLP_InitFC1_P  = 8'h40,  // Posted
    DLLP_InitFC1_NP = 8'h50,  // Non-Posted
    DLLP_InitFC1_Cpl= 8'h60,  // Completion
    DLLP_InitFC2_P  = 8'h44,
    DLLP_InitFC2_NP = 8'h54,
    DLLP_InitFC2_Cpl= 8'h64,
    DLLP_UpdateFC_P = 8'hC0,
    DLLP_UpdateFC_NP= 8'hD0,
    DLLP_UpdateFC_C = 8'hE0,
    DLLP_NullDLLP   = 8'hF0
  } dllp_type_e;

  // -----------------------------------------------------------------------
  // LTSSM States
  // -----------------------------------------------------------------------
  typedef enum logic [4:0] {
    LTSSM_DETECT_QUIET    = 5'h00,
    LTSSM_DETECT_ACTIVE   = 5'h01,
    LTSSM_POLLING_ACTIVE  = 5'h02,
    LTSSM_POLLING_CFG     = 5'h03,
    LTSSM_CFG_LNKWD_STR  = 5'h04,
    LTSSM_CFG_LNKWD_ACPT = 5'h05,
    LTSSM_CFG_LNKNUM_WAIT = 5'h06,
    LTSSM_CFG_LNKNUM_ACPT = 5'h07,
    LTSSM_CFG_COMPLETE    = 5'h08,
    LTSSM_CFG_IDLE        = 5'h09,
    LTSSM_L0              = 5'h10,
    LTSSM_L0s_TX          = 5'h11,
    LTSSM_L0s_RX          = 5'h12,
    LTSSM_L1              = 5'h13,
    LTSSM_L2              = 5'h14,
    LTSSM_RECOVERY_RCVR   = 5'h15,
    LTSSM_RECOVERY_SPEED  = 5'h16,
    LTSSM_RECOVERY_RCVR_CFG = 5'h17,
    LTSSM_RECOVERY_IDLE   = 5'h18,
    LTSSM_HOT_RESET       = 5'h19,
    LTSSM_LOOPBACK_ENTRY  = 5'h1A,
    LTSSM_LOOPBACK_ACTIVE = 5'h1B,
    LTSSM_LOOPBACK_EXIT   = 5'h1C,
    LTSSM_DISABLED         = 5'h1F
  } ltssm_state_e;

  // -----------------------------------------------------------------------
  // Completion Status
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    CPL_SC  = 3'b000,  // Successful Completion
    CPL_UR  = 3'b001,  // Unsupported Request
    CPL_CRS = 3'b010,  // Config Request Retry Status
    CPL_CA  = 3'b100   // Completer Abort
  } cpl_status_e;

  // -----------------------------------------------------------------------
  // Link Speed / Width
  // -----------------------------------------------------------------------
  typedef enum logic [3:0] {
    GEN1 = 4'h1,   // 2.5 GT/s
    GEN2 = 4'h2,   // 5.0 GT/s
    GEN3 = 4'h3,   // 8.0 GT/s
    GEN4 = 4'h4,   // 16.0 GT/s
    GEN5 = 4'h5    // 32.0 GT/s
  } link_speed_e;

  typedef enum logic [4:0] {
    WIDTH_X1  = 5'h01,
    WIDTH_X2  = 5'h02,
    WIDTH_X4  = 5'h04,
    WIDTH_X8  = 5'h08,
    WIDTH_X16 = 5'h10
  } link_width_e;

  // -----------------------------------------------------------------------
  // TLP Header struct (generic — overlay fmt/type specific fields)
  // -----------------------------------------------------------------------
  typedef struct packed {
    logic [2:0]  fmt;
    logic [4:0]  tlp_type;
    logic        t9;
    logic [2:0]  tc;
    logic        t8;
    logic        attr2;
    logic        ln;
    logic        th;
    logic        td;
    logic        ep;
    logic [1:0]  attr;
    logic [1:0]  at;
    logic [9:0]  length;
  } tlp_hdr_dw0_t;

  // -----------------------------------------------------------------------
  // Flow Control Credit type
  // -----------------------------------------------------------------------
  typedef struct packed {
    logic [11:0] hdr_credits;
    logic [11:0] data_credits;
  } fc_credits_t;

  // -----------------------------------------------------------------------
  // Error type for AER
  // -----------------------------------------------------------------------
  typedef enum logic [4:0] {
    ERR_NONE           = 5'h00,
    ERR_ECRC           = 5'h01,
    ERR_BAD_TLP        = 5'h02,
    ERR_BAD_DLLP       = 5'h03,
    ERR_REPLAY_ROLLOVER= 5'h04,
    ERR_REPLAY_TIMEOUT = 5'h05,
    ERR_MALFORMED_TLP  = 5'h10,
    ERR_UNSUPPORTED_REQ= 5'h11,
    ERR_COMPLETER_ABORT= 5'h12,
    ERR_UNEXPECTED_CPL = 5'h13,
    ERR_RECEIVER_OVERFLOW = 5'h14,
    ERR_POISONED_TLP   = 5'h15,
    ERR_DATA_LINK_PROTO= 5'h16,
    ERR_SURPRISE_DOWN  = 5'h17,
    ERR_FLOW_CTRL      = 5'h18
  } pcie_error_e;

  // Power Management State
  typedef enum logic [2:0] {
    PM_D0         = 3'h0,
    PM_D1         = 3'h1,
    PM_D2         = 3'h2,
    PM_D3hot      = 3'h3,
    PM_D3cold     = 3'h4
  } pm_state_e;

endpackage : pcie_pkg
