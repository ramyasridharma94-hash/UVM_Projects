# DDR5 IP Specification

## Overview
Full DDR5/LPDDR5 memory controller IP with AXI4 host interface, DFI PHY interface,
ECC (SEC-DED), ZQ calibration, multi-mode refresh, and 7-stage PHY training.

## Supported Standards
- JEDEC DDR5 SDRAM (JESD79-5B) — 4800 / 5600 / 6400 / 7200 / 8400 MT/s
- JEDEC LPDDR5/LPDDR5X (JESD209-5C) — 6400 / 7500 MT/s
- DFI 5.0 specification

## Architecture

```
AXI4 Host ─→ [APB Config] ─→ Timing/Mode Registers
                              ↓
              [DDR5 Controller Top]
              ├── Command Scheduler (tFAW, tRRD_S/L, OoO)
              ├── Bank FSMs ×32 (tRCD, tRP, tRAS, tWR, tRTP)
              ├── Refresh Controller (Normal/FGR-2x/4x/PBR/SBR)
              ├── ZQ Controller (tZQinit, tZQoper, periodic)
              └── Inline ECC (SEC-DED Hamming(72,64))
                              ↓ DFI 5.0
              [DDR5 PHY Top]
              ├── DLL (0°/90°/180°/270° phases, per-speed calibration)
              ├── DFI Controller (1:2 freq ratio, WL/RL timing)
              └── IO Buffers (programmable ODT, ZQ, DMI)
                              ↓
              DRAM Pads: CK±, CA[13:0], CS_n, CKE, ODT, RESET_n
                         DQ[31:0], DQS±[3:0], DM[3:0]
```

## RTL File Map

| File | Module | Description |
|------|--------|-------------|
| `rtl/ctrl/ddr5_cmd_scheduler.sv` | `ddr5_cmd_scheduler` | OoO scheduler, tFAW/tRRD windows |
| `rtl/ctrl/ddr5_bank_fsm.sv` | `ddr5_bank_fsm` | Per-bank state machine (×32) |
| `rtl/ctrl/ddr5_refresh_ctrl.sv` | `ddr5_refresh_ctrl` | Normal/FGR/PBR/SBR refresh engine |
| `rtl/ctrl/ddr5_zq_ctrl.sv` | `ddr5_zq_ctrl` | ZQCAL_Start/Latch, periodic ZQ |
| `rtl/ctrl/ddr5_ecc.sv` | `ddr5_ecc` | SEC-DED Hamming(72,64) encode/decode |
| `rtl/ctrl/ddr5_ctrl_top.sv` | `ddr5_ctrl_top` | Controller integration top |
| `rtl/phy/ddr5_dll.sv` | `ddr5_dll` | DLL with speed-adaptive code |
| `rtl/phy/ddr5_io_buf.sv` | `ddr5_io_buf` | Bidirectional DQ/DQS IO pads |
| `rtl/phy/ddr5_dfi_ctrl.sv` | `ddr5_dfi_ctrl` | DFI 1:2 framing, WL/RL pipeline |
| `rtl/phy/ddr5_phy_top.sv` | `ddr5_phy_top` | PHY integration top |
| `rtl/ddr5_ip_top.sv` | `ddr5_ip_top` | Full IP top with AXI4 + APB config |

## Key Features

### Command Scheduler
- 8-entry per-bank command queue
- Out-of-order execution across bank groups
- tFAW enforcement (4-ACT sliding window)
- tRRD_S/L (same/different bank group)
- Refresh priority insertion

### Bank State Machines (×32)
- States: IDLE → ACTIVATING → ACTIVE → PRECHARGING → REFRESHING
- tRCD, tRP, tRAS, tWR, tRTP all enforced
- Auto-precharge (WRA/RDA) with tWR/tRTP countdown
- Same-bank refresh override

### ECC (Hamming SEC-DED)
- 64-bit data + 8 check bits per sub-channel
- Single-bit error correction (corrected transparently)
- Double-bit error detection (reported as uncorrectable)
- Inline ECC mode (MR15[1:0])

### Refresh Modes
| Mode | Interval | Description |
|------|----------|-------------|
| Normal | tREFI=3.9µs | All-bank refresh (CMD_REF) |
| FGR-2x | tREFI/2 | Fine granularity 2x rate |
| FGR-4x | tREFI/4 | Fine granularity 4x rate |
| PBR | per-bank | Per-bank refresh (CMD_REFPB) |
| SBR | per-bank | Same-bank refresh (LPDDR5) |

### PHY Training Sequence
1. ZQ Calibration (ZQCAL_Long → ZQCAL_Latch)
2. CA Training (VrefCA sweep, eye centering)
3. Write Leveling (wdqs_delay sweep)
4. Read DQS Centering (rdqs_delay sweep)
5. Write DQ Training (per-bit margin)
6. VREF DQ Optimization (6.25% step, 60–80% VDD)
7. VREF CA Optimization

### APB Configuration Register Map
| Offset | Register | Description |
|--------|----------|-------------|
| 0x000 | TIMING_TCL | CAS Latency |
| 0x004 | TIMING_TCWL | Write Latency |
| 0x008 | TIMING_TRCD | RAS-to-CAS delay |
| 0x00C | TIMING_TRP | Precharge time |
| 0x010 | TIMING_TRAS | Row active time |
| 0x014 | TIMING_TRFC | Refresh cycle time |
| 0x018 | TIMING_TREFI | Refresh interval |
| 0x020 | REF_MODE | Refresh mode select |
| 0x024 | ECC_MODE | ECC mode |
| 0x028 | TRAIN_MODE | Training trigger |
| 0x100–0x120 | MR0–MR37 | Mode register shadows |
| 0x200 | STATUS | init_done, dll_locked |
| 0x204 | REF_DEBT | Pending refresh count |
| 0x208 | AER_ERR | Last AER error type |

## Running Simulation

```bash
# Protocol UVM testbench (protocols/ddr5/sim/)
cd protocols/ddr5/sim/
make write    # Write test (BL8/BL16, AP, wmask)
make read     # Read test (BL8/BL16/BC4)
make refresh  # Refresh modes (Normal/FGR/PBR/SBR)
make mrs      # Mode register programming
make train    # PHY training (ZQ/CA/WL/DQS/VREF)
make pm       # Power management (PD/SREF)
make err      # Error injection (parity/ECC/CRC/ALERT)
make lp5      # LPDDR5 features (BL16/dual-ch/DPD/PASR)
make regress  # All 8 tests

# Full IP simulation (ddr5_ip/sim/)
cd ddr5_ip/sim/
make regress  # Runs all protocol tests against IP RTL
```
