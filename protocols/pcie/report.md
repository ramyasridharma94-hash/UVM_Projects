# PCIe Protocol UVM Verification Project

## Overview
Full UVM verification environment for PCI Express (PCIe) Gen1–Gen5, covering all
three protocol layers: Physical, Data Link, and Transaction.

---

## Directory Structure

```
pcie/
├── rtl/
│   ├── pcie_pkg.sv          — shared enums/structs (tlp_type_e, ltssm_state_e, …)
│   ├── pcie_phy.sv          — Physical Layer: LTSSM, lane mgmt, speed negotiation
│   ├── pcie_dll.sv          — Data Link Layer: seq#, ACK/NAK, retry buffer, FC
│   ├── pcie_tlp_tx.sv       — TL Transmitter: all TLP types, ECRC, FC gating
│   ├── pcie_tlp_rx.sv       — TL Receiver: header parsing, dispatch, ECRC check
│   └── pcie_top.sv          — Integration top
├── tb/
│   ├── interface/
│   │   └── pcie_if.sv       — Clocking blocks, modports, SVA assertions
│   ├── agent/
│   │   ├── pcie_tlp_seq_item.sv   — TLP sequence item (all types, constraints)
│   │   ├── pcie_dllp_seq_item.sv  — DLLP sequence item (ACK/NAK/FC/PM)
│   │   ├── pcie_driver.sv         — Link init + TLP driving
│   │   ├── pcie_monitor.sv        — 7 analysis ports (posted/NP/cpl/cfg/err/pm/LTSSM)
│   │   ├── pcie_sequencer.sv
│   │   ├── pcie_agent.sv
│   │   └── pcie_agent_pkg.sv      — compile-order package
│   ├── sequences/
│   │   ├── pcie_base_seq.sv
│   │   ├── pcie_mem_rd_seq.sv     — MRd32/64, MRdLk, directed variants
│   │   ├── pcie_mem_wr_seq.sv     — MWr32/64, directed, poisoned EP
│   │   ├── pcie_cfg_rd_seq.sv     — CfgRd Type0/1 register sweep
│   │   ├── pcie_cfg_wr_seq.sv     — CfgWr Type0/1 BAR programming
│   │   ├── pcie_msg_seq.sv        — PME, INTx, Err, Vendor msgs
│   │   ├── pcie_cpl_seq.sv        — Cpl/CplD/CplLk, split completion
│   │   ├── pcie_err_seq.sv        — AER error injection + sweep
│   │   ├── pcie_pm_seq.sv         — ASPM L1 entry/exit, PME
│   │   ├── pcie_msi_seq.sv        — MSI (1/8 vectors), MSI-X (32 vectors)
│   │   ├── pcie_fc_seq.sv         — FC stress, credit exhaustion, recovery
│   │   ├── pcie_atomicop_seq.sv   — FetchAdd/Swap/CAS 32b and 64b
│   │   └── pcie_ltssm_seq.sv      — Train, SpeedChange, Recovery, Loopback, Disable
│   ├── env/
│   │   ├── pcie_scoreboard.sv     — tag tracking, cpl matching, AER, summary
│   │   ├── pcie_coverage.sv       — 10 covergroups incl. TC×Type cross
│   │   └── pcie_env.sv
│   ├── tests/
│   │   ├── pcie_base_test.sv
│   │   ├── pcie_mem_access_test.sv
│   │   ├── pcie_cfg_access_test.sv
│   │   ├── pcie_error_test.sv
│   │   ├── pcie_pm_test.sv
│   │   ├── pcie_msi_test.sv
│   │   ├── pcie_fc_test.sv
│   │   ├── pcie_ltssm_test.sv
│   │   ├── pcie_atomicop_test.sv
│   │   └── pcie_virtual_ch_test.sv
│   └── top/
│       └── tb_top.sv
└── sim/
    └── Makefile
```

---

## PCIe Features Covered

### Transaction Layer (TL)
| Feature | Implementation |
|---------|---------------|
| MRd32 / MRd64 | pcie_tlp_tx, pcie_tlp_rx, pcie_mem_rd_seq |
| MRdLk32 / MRdLk64 | pcie_mem_rd_seq |
| MWr32 / MWr64 | pcie_tlp_tx, pcie_mem_wr_seq |
| IORd / IOWr | pcie_tlp_tx, pcie_tlp_rx |
| CfgRd0/1 & CfgWr0/1 | pcie_tlp_tx, pcie_cfg_rd/wr_seq |
| Msg / MsgD (PME, INTx, Error, Vendor) | pcie_msg_seq |
| Cpl / CplD / CplLk / CplDLk | pcie_cpl_seq, scoreboard tag matching |
| Split completions | pcie_split_cpl_seq |
| AtomicOp: FetchAdd, Swap, CAS (32/64b) | pcie_atomicop_seq/test |
| ECRC generation and checking | pcie_tlp_tx CRC-32, pcie_tlp_rx TD check |
| Error Poisoned (EP bit) | pcie_tlp_seq_item.ep, pcie_mem_wr_seq |
| Traffic Classes TC0–TC7 | pcie_tlp_seq_item.tc, cg_traffic_class, vc_test |
| 10-bit extended tag | pcie_tlp_seq_item.tag[9:0] |
| Address types (AT bits, TH hints, LN) | pcie_tlp_seq_item |

### Data Link Layer (DLL)
| Feature | Implementation |
|---------|---------------|
| 12-bit sequence numbers (TX/RX) | pcie_dll.sv |
| ACK / NAK DLLPs | pcie_dll.sv, pcie_dllp_seq_item |
| Retry buffer (256-deep) | pcie_dll.sv |
| ACK latency timer | pcie_dll.sv |
| Replay on NAK (up to 4 retries) | pcie_dll.sv |
| FC: InitFC1/InitFC2/UpdateFC | pcie_dll.sv, pcie_fc_seq |
| PM DLLPs (L1 entry, ACK) | pcie_dll.sv, pcie_pm_seq |
| Null DLLP | pcie_dllp_seq_item |

### Physical Layer (PHY)
| Feature | Implementation |
|---------|---------------|
| LTSSM (21 states) | pcie_phy.sv |
| Link training (Detect→Polling→Config→L0) | pcie_phy.sv, pcie_ltssm_seq |
| L0s TX/RX (ASPM) | pcie_phy.sv |
| L1 / L2 states | pcie_phy.sv, pcie_pm_seq |
| Recovery (RCVR/SPEED/CFG/IDLE) | pcie_phy.sv, pcie_ltssm_seq |
| Speed change Gen1→Gen5 | pcie_phy.sv, pcie_ltssm_seq |
| Link disable / hot reset | pcie_phy.sv, pcie_ltssm_seq |
| Loopback (active/exit) | pcie_phy.sv, pcie_ltssm_seq |
| Electrical idle detection | pcie_phy.sv (rx_elec_idle) |
| TS1/TS2 ordered set detection | pcie_phy.sv |
| Multi-lane (x1/x2/x4/x8/x16) | pcie_phy.sv, pcie_if |

### Error Handling (AER)
| Error | Correctable/Uncorrectable |
|-------|--------------------------|
| ECRC | Correctable |
| Bad TLP / Bad DLLP | Correctable |
| Replay Timeout / Rollover | Correctable |
| Malformed TLP | Uncorrectable |
| Unsupported Request | Uncorrectable |
| Completer Abort | Uncorrectable |
| Unexpected Completion | Uncorrectable |
| Poisoned TLP | Uncorrectable |
| Data Link Protocol Error | Uncorrectable |
| Receiver Overflow | Uncorrectable |
| Surprise Down | Uncorrectable |

### Interrupts
- MSI: up to 8 vectors, address/data programming
- MSI-X: up to 32 vectors, table programming in BAR space
- Legacy INTx: Assert/Deassert INTA messages

### Power Management
- ASPM L0s, L1 entry via DLLP
- PME, PME_TO_ACK messages
- D0/D1/D2/D3hot state transitions (modeled in pm_state_e)

### Virtual Channels
- TC0–TC7 supported via seq_item.tc
- TC×TLP-type cross coverage in pcie_coverage

---

## Running Simulations (VCS)

```bash
cd sim/

# Default test
make

# Specific test
make TESTNAME=pcie_ltssm_test

# Quick targets
make mem      # Memory access test
make cfg      # Config space test
make err      # AER error injection test
make pm       # Power management test
make msi      # MSI/MSI-X interrupt test
make fc       # Flow control test
make ltssm    # LTSSM training & recovery test
make atomic   # AtomicOp test
make vc       # Virtual channel test

# Full regression
make regress

# Seed sweep (randomized)
make seed_sweep TESTNAME=pcie_mem_access_test

# Increase verbosity
make TESTNAME=pcie_error_test UVM_VERBOSITY=UVM_HIGH
```

---

## Scoreboard Checks
- In-flight tag tracking (no collisions)
- Completion-to-request matching
- Byte count vs request length validation
- Unexpected completion detection
- AER error accumulation and reporting
- Unmatched requests flagged at end-of-simulation

## Coverage Groups (10 total)
1. `cg_tlp_type` — all 24 TLP types
2. `cg_traffic_class` — TC0–TC7
3. `cg_tlp_length` — DW ranges (1/2-4/5-16/17-64/65-256/max)
4. `cg_cpl_status` — SC, UR, CRS, CA
5. `cg_errors` — all 14 AER error types
6. `cg_tlp_attr` — relaxed ordering, no-snoop combinations
7. `cg_addr_space` — 32-bit vs 64-bit address space
8. `cg_byte_enables` — first_be/last_be patterns
9. `cg_cross_type_tc` — Posted/NP/Cpl/Atomic × TC0-TC7
10. `cg_tag` — 8-bit vs 10-bit extended tag coverage

## SVA Assertions (in pcie_if.sv)
- `p_req_stable` — request signals stable while pending
- `p_cpl_valid_tag` — completion tag is defined
- `p_tlp_needs_link_up` — no TLP accepted when link is down
