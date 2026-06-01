# UCIe Protocol UVM Verification — Execution Flow Report

## Table of Contents

1. [Protocol Overview](#1-protocol-overview)
2. [DUT Architecture](#2-dut-architecture)
3. [Testbench Hierarchy](#3-testbench-hierarchy)
4. [UVM Phase Execution](#4-uvm-phase-execution)
5. [Signal Flow and Timing](#5-signal-flow-and-timing)
6. [Credit-Based Flow Control](#6-credit-based-flow-control)
7. [Scoreboard Checking Flow](#7-scoreboard-checking-flow)
8. [Test Scenarios](#8-test-scenarios)
9. [Coverage Model](#9-coverage-model)
10. [Simulation Commands](#10-simulation-commands)

---

## 1. Protocol Overview

**UCIe (Universal Chiplet Interconnect Express)** is an open industry standard for Die-to-Die (D2D) chiplet interconnect. This project implements and verifies the **Main Band adapter layer** — the layer responsible for transporting 256-bit flits between chiplets using credit-based flow control.

### Key Concepts Modeled

| Concept | Implementation |
|---|---|
| Flit width | 256 bits (one UCIe flit per transaction) |
| Flow control | Credit-based: RX pre-grants FIFO_DEPTH credits to TX |
| Buffering | 8-slot deep FIFO in TX adapter |
| Credit return | RX pulses `credit_return` 1 cycle after accepting a flit |
| Loopback | TX output feeds RX input (standalone DUT verification) |
| Clock | 100 MHz (10 ns period) |

---

## 2. DUT Architecture

### Block Diagram

```
                    ucie_adapter_top
  +---------------------------------------------------------+
  |                                                         |
  |  Host TX Interface         Internal Link         Host RX Interface
  |                                                         |
  |  tx_flit_data[255:0] -->+------------------+            |
  |  tx_flit_valid       -->| ucie_tx          |            |
  |  tx_flit_ready       <--|                  |            |
  |                         |  8-slot FIFO     |            |
  |                         |  credit counter  |            |
  |                         |  (CREDIT_W=4b)   | link_data  |
  |                         |                  |----------->+---> ucie_rx
  |                         |  fill[3:0]       | link_valid |
  |                         |  credits[3:0]    |----------->+
  |                         +------------------+            |
  |                                    ^                    |
  |                         credit_return (1 cycle delay)   |
  |                                    |                    |
  |                         +----------+----------+         |
  |                         | ucie_rx             |         |
  |                         |                     |         |
  |                         | link_data  --> reg  |--> rx_flit_data[255:0]
  |                         | link_valid --> reg  |--> rx_flit_valid
  |                         |            --> reg  |--> credit_return
  |                         +---------------------+         |
  +---------------------------------------------------------+
```

### Module Descriptions

**`ucie_tx` (rtl/ucie_tx.sv)**

The TX adapter contains:
- **FIFO**: 8 slots of 256-bit storage, circular buffer with `wr_ptr`/`rd_ptr`
- **fill counter** (4-bit): tracks number of occupied FIFO slots
- **credits counter** (4-bit): tracks credits granted by RX (initialized to 8)

Key combinatorial logic:
```
flit_ready = (fill < FIFO_DEPTH)        // host can push when FIFO not full
link_valid = (fill > 0) && (credits > 0) // TX sends when FIFO non-empty AND credited
push       = flit_valid && flit_ready    // host-side acceptance
pop        = link_valid                  // link-side transmission
```

Sequential (clock-edge) updates:
- `push && !pop`  → `fill + 1`
- `!push && pop`  → `fill - 1`
- `pop && !credit_return` → `credits - 1`
- `!pop && credit_return` → `credits + 1`

**`ucie_rx` (rtl/ucie_rx.sv)**

Single always_ff block. On every posedge:
```
flit_out       <= link_data    // register incoming flit
flit_out_valid <= link_valid   // register valid flag
credit_return  <= link_valid   // return credit 1 cycle after accepting
```

**`ucie_adapter_top` (rtl/ucie_adapter_top.sv)**

Top-level wrapper. Wires `u_tx → link_data/link_valid → u_rx` and feeds `u_rx.credit_return` back to `u_tx.credit_return`. Parameters: `FLIT_WIDTH=256`, `FIFO_DEPTH=8`.

---

## 3. Testbench Hierarchy

### UVM Component Tree

```
uvm_test_top  (ucie_single_flit_test / ucie_burst_flit_test)
  └── env  (ucie_env)
        ├── agent  (ucie_agent)  [UVM_ACTIVE]
        │     ├── seqr  (ucie_sequencer)
        │     ├── drv   (ucie_driver)
        │     └── mon   (ucie_monitor)
        │           ├── tx_ap  ──> agent.tx_ap ──> sb.tx_export
        │           └── rx_ap  ──> agent.rx_ap ──> sb.rx_export
        │                                     └──> cov.analysis_export
        ├── sb   (ucie_scoreboard)
        └── cov  (ucie_coverage)
```

### File Map

```
protocols/ucie/
├── rtl/
│   ├── ucie_tx.sv              Credit-based TX FIFO adapter
│   ├── ucie_rx.sv              Registered RX + credit return
│   └── ucie_adapter_top.sv     Top-level loopback DUT
├── tb/
│   ├── interface/
│   │   └── ucie_if.sv          SV interface with master_cb / monitor_cb
│   ├── agent/
│   │   ├── ucie_seq_item.sv    flit_data[255:0], flit_type[1:0]
│   │   ├── ucie_sequencer.sv   Standard UVM sequencer
│   │   ├── ucie_driver.sv      Drives TX: waits ready, asserts valid 1 cycle
│   │   ├── ucie_monitor.sv     Dual-thread: monitors TX accept + RX output
│   │   ├── ucie_agent.sv       Assembles seqr+drv+mon; exposes tx_ap/rx_ap
│   │   └── ucie_agent_pkg.sv   Package encapsulating all agent files
│   ├── sequences/
│   │   ├── ucie_base_seq.sv    Empty base
│   │   ├── ucie_single_flit_seq.sv   N random flits, one at a time
│   │   └── ucie_burst_flit_seq.sv    All-0, all-1, then N random flits
│   ├── env/
│   │   ├── ucie_scoreboard.sv  Two-sided: write_tx() / write_rx()
│   │   ├── ucie_coverage.sv    Coverpoints: data_lo, data_hi, flit_type
│   │   └── ucie_env.sv         Builds agent+sb+cov, connects analysis ports
│   ├── tests/
│   │   ├── ucie_base_test.sv   Builds env; trivial 100ns run
│   │   ├── ucie_single_flit_test.sv  Runs single_flit_seq (4 flits)
│   │   └── ucie_burst_flit_test.sv   Runs burst_flit_seq (18 flits)
│   └── top/
│       └── tb_top.sv           Clock/reset gen, DUT, config_db, run_test()
└── sim/
    └── Makefile                VCS targets: all / compile / run / regress / clean
```

---

## 4. UVM Phase Execution

### Phase Timeline

```
SIMULATION START
│
├─ build_phase (bottom-up construct, top-down build)
│   tb_top
│     run_test()  →  UVM factory instantiates test
│   ucie_*_test::build_phase
│     env = ucie_env::type_id::create(...)
│   ucie_env::build_phase
│     agent = ucie_agent::type_id::create(...)
│     sb    = ucie_scoreboard::type_id::create(...)
│     cov   = ucie_coverage::type_id::create(...)
│   ucie_agent::build_phase
│     tx_ap, rx_ap ports created
│     mon  = ucie_monitor::type_id::create(...)
│     seqr = ucie_sequencer::type_id::create(...)   [UVM_ACTIVE]
│     drv  = ucie_driver::type_id::create(...)      [UVM_ACTIVE]
│   ucie_monitor::build_phase
│     tx_ap, rx_ap created; vif fetched from config_db
│   ucie_driver::build_phase
│     vif fetched from config_db
│   ucie_scoreboard::build_phase
│     tx_export, rx_export created
│
├─ connect_phase
│   ucie_agent::connect_phase
│     drv.seq_item_port  →  seqr.seq_item_export
│     mon.tx_ap          →  agent.tx_ap
│     mon.rx_ap          →  agent.rx_ap
│   ucie_env::connect_phase
│     agent.tx_ap  →  sb.tx_export
│     agent.rx_ap  →  sb.rx_export
│     agent.rx_ap  →  cov.analysis_export
│
├─ start_of_simulation_phase
│   (UVM default: print topology)
│
├─ run_phase  ─────── TIME ADVANCES ──────────────────────────
│   │
│   ├─ tb_top reset sequence
│   │    t=0:   rst_n = 0
│   │    t=100: rst_n = 1  (after 10 posedges × 10ns)
│   │
│   ├─ ucie_driver::run_phase
│   │    initialise tx_flit_valid=0, tx_flit_data=0
│   │    wait posedge clk iff rst_n=1  (unblocks at t=100ns)
│   │    enter forever loop: get_next_item → drive_flit → item_done
│   │
│   ├─ ucie_monitor::run_phase
│   │    fork { monitor_tx(), monitor_rx() } — run in parallel forever
│   │
│   ├─ ucie_*_test::run_phase
│   │    raise_objection
│   │    seq.start(env.agent.seqr)  →  sequences execute (see §8)
│   │    #200 / #500 drain time
│   │    drop_objection
│   │
│   └─ UVM kernel: objection count → 0 → end run_phase
│
├─ extract_phase  /  check_phase  /  report_phase
│   ucie_scoreboard::report_phase
│     prints  "UCIe SB: PASS=N FAIL=0"
│     if fail_count > 0 or exp_q not empty → UVM_ERROR
│     else → "TEST PASSED"
│
└─ SIMULATION END  ($finish)
```

---

## 5. Signal Flow and Timing

### Single Flit — Cycle-by-Cycle Trace

```
Cycle   Signal                   Value     Event
─────────────────────────────────────────────────────────────────────
 0      rst_n                    0         DUT in reset
        credits (TX)             8         (initialized on reset)
        fill (TX)                0

 10     rst_n                    1         Reset released

 11     driver: waits for        READY=1   FIFO empty → flit_ready high
        tx_flit_ready

        driver drives:
        tx_flit_data             0xABCD... 256-bit random flit
        tx_flit_valid            1

─── posedge Cycle 12 ──────────────────────────────────────────
        DUT: push fires (valid=1, ready=1)
          fifo[0] ← 0xABCD...
          wr_ptr  ← 1
          fill    ← 1
          link_valid ← 1  (fill>0, credits=8>0)  [combinatorial]

        driver: deasserts tx_flit_valid ← 0

        monitor_tx: sees valid=1 && ready=1
          creates tx_item, calls tx_ap.write(tx_item)
          → sb.write_tx():  exp_q.push_back(0xABCD...)

─── posedge Cycle 13 ──────────────────────────────────────────
        DUT TX: pop fires (link_valid=1)
          rd_ptr  ← 1
          fill    ← 0
          credits ← 7  (pop fired, no credit_return yet)

        DUT RX (ucie_rx):
          flit_out       ← link_data (0xABCD...)
          flit_out_valid ← 1
          credit_return  ← 1          ← RX returns credit

─── posedge Cycle 14 ──────────────────────────────────────────
        DUT TX sees credit_return=1
          credits ← 8   (restored)
        DUT: link_valid=0 (fill=0, FIFO empty)

        monitor_rx: sees rx_flit_valid=1
          creates rx_item (flit_data = 0xABCD...)
          calls rx_ap.write(rx_item)
          → sb.write_rx():
              exp = exp_q.pop_front()  =  0xABCD...
              compare: item.flit_data === exp  →  MATCH, pass_count++
          → cov.write():  ucie_cg.sample()

        DUT: flit_out_valid ← 0, credit_return ← 0
─────────────────────────────────────────────────────────────────────

    TX→RX latency = 2 clock cycles (1 pop cycle + 1 RX register cycle)
```

### Interface Clocking Block Timing

```
                  #1ns setup/hold applied by clocking blocks
                  ↓
clk      ─────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────
              └──┘      └──┘      └──┘      └──┘
              N        N+1       N+2       N+3

tx_flit_valid ─────────────────┐  ┌────
                               └──┘
tx_flit_ready ────────────────────────   (combinatorial: fill < FIFO_DEPTH)

DUT push fires                   ↑ N+1

link_valid    ────────────────────────────────┐  ┌────
(combinatorial)                              └──┘
rx_flit_valid                                        ┌──────
(registered)  ────────────────────────────────────── ┘

monitor_tx fires at: N+1 (sees valid && ready)
monitor_rx fires at: N+3 (sees rx_flit_valid)
```

---

## 6. Credit-Based Flow Control

### Credit State Machine

```
RESET STATE:
  credits = 8  (FIFO_DEPTH pre-granted by RX)
  fill    = 0

NORMAL FLOW:
  ┌─────────────────────────────────────────────────┐
  │  Host pushes flit              DUT pops flit    │
  │  push = valid && ready         pop = fill>0 &&  │
  │                                      credits>0  │
  │  fill += 1  (push, no pop)     fill -= 1        │
  │  credits unchanged             credits -= 1     │
  │                                                 │
  │                                    ↓ 1 cycle    │
  │                               RX: credit_return=1│
  │                               TX: credits += 1  │
  └─────────────────────────────────────────────────┘

STEADY STATE (continuous flow):
  Cycle N:   pop fires,  credits: 8 → 7
  Cycle N+1: credit_return=1 AND next pop fires simultaneously
             credits: 7 - 1 + 1 = 7  (stable)

FIFO FULL (host faster than link, credits exhausted):
  fill = 8  →  flit_ready = 0  →  host stalled
  (In loopback, TX pops as fast as host pushes; fill stays ≤ 1 in steady state)

CREDIT EXHAUSTED (if RX stalls, not applicable in loopback):
  credits = 0  →  link_valid = 0  →  TX stops sending
  TX waits until credit_return pulse
```

### Credit Flow Diagram

```
  TB / Driver              ucie_tx                  ucie_rx
     │                        │                        │
     │── flit_valid ──────────>│                        │
     │<── flit_ready ──────────│ (fill < FIFO_DEPTH)    │
     │                        │                        │
     │                        │── link_valid ──────────>│
     │                        │── link_data ───────────>│ register
     │                        │    credits -= 1         │
     │                        │                        │── rx_flit_valid ──> monitor
     │                        │<── credit_return ───────│ (1 cycle later)
     │                        │    credits += 1         │
     │                        │                        │
```

---

## 7. Scoreboard Checking Flow

The scoreboard uses two separate `uvm_analysis_imp` ports (declared with `uvm_analysis_imp_decl`) to independently handle TX-side and RX-side observations.

```
                     ucie_scoreboard
                    ┌──────────────────────────────────┐
monitor.tx_ap ────> │ tx_export → write_tx(item)       │
                    │   exp_q.push_back(item.flit_data) │
                    │                                  │
monitor.rx_ap ────> │ rx_export → write_rx(item)       │
                    │   exp = exp_q.pop_front()         │
                    │   if item.flit_data !== exp:      │
                    │       UVM_ERROR("MISMATCH")       │
                    │       fail_count++                │
                    │   else:                           │
                    │       pass_count++                │
                    └──────────────────────────────────┘

report_phase:
  if fail_count > 0 OR exp_q not empty → UVM_ERROR "TEST FAILED"
  else                                 → UVM_INFO  "TEST PASSED"
```

### Scoreboard Check Sequence (4 flits)

```
Time    Event                           exp_q state        SB action
──────────────────────────────────────────────────────────────────────
 t1     write_tx(flit_0)               [flit_0]            enqueue
 t3     write_rx(flit_0)               []                  MATCH ✓
 t4     write_tx(flit_1)               [flit_1]            enqueue
 t6     write_rx(flit_1)               []                  MATCH ✓
 t7     write_tx(flit_2)               [flit_2]            enqueue
 t9     write_rx(flit_2)               []                  MATCH ✓
 t10    write_tx(flit_3)               [flit_3]            enqueue
 t12    write_rx(flit_3)               []                  MATCH ✓
report  pass_count=4, fail_count=0     empty               PASSED
```

---

## 8. Test Scenarios

### Test 1: `ucie_single_flit_test`

**Purpose:** Verify basic flit transfer — one flit at a time, 4 total.

**Sequence:** `ucie_single_flit_seq` (`num_flits = 4`)

```
run_phase:
  1. raise_objection
  2. seq = ucie_single_flit_seq::create()
  3. seq.num_flits = 4
  4. seq.start(env.agent.seqr)
       repeat(4):
         create req
         randomize req  (flit_data = random 256-bit, flit_type = 2'b00)
         start_item(req) → driver.drive_flit(req)
         finish_item(req)
  5. #200ns  (flush 2-cycle pipeline; 20 cycles headroom)
  6. drop_objection → report_phase
```

**Stimulus:**
```
  Flit 0: random 256-bit data
  Flit 1: random 256-bit data
  Flit 2: random 256-bit data
  Flit 3: random 256-bit data
```

**Pass Criteria:** `pass_count = 4`, `fail_count = 0`, `exp_q` empty at report.

---

### Test 2: `ucie_burst_flit_test`

**Purpose:** Stress FIFO and credit-return mechanism with 18 back-to-back flits.

**Sequence:** `ucie_burst_flit_seq` (`num_flits = 16`)

```
run_phase:
  1. raise_objection
  2. seq = ucie_burst_flit_seq::create()
  3. seq.num_flits = 16
  4. seq.start(env.agent.seqr)
       Flit 0: all-zeros  (256'h0)
       Flit 1: all-ones   (256'hFF...FF)
       Flits 2-17: 16 randomized 256-bit flits
  5. #500ns  (50 cycles; allows 18 flits to fully drain)
  6. drop_objection → report_phase
```

**Stimulus pattern:**

```
  Flit  0: 0x0000_0000_..._0000  (all zeros — boundary pattern)
  Flit  1: 0xFFFF_FFFF_..._FFFF  (all ones  — boundary pattern)
  Flits 2-17: random 256-bit data (credit replenishment under load)
```

**What is verified:**
- All-zero and all-one data travel through FIFO and RX register without corruption
- Back-to-back delivery: flit N+1 starts while flit N is still in the TX pipeline
- Credit counter stays consistent under sustained 18-flit load
- Scoreboard confirms all 18 flits match in-order

**Pass Criteria:** `pass_count = 18`, `fail_count = 0`.

---

## 9. Coverage Model

Defined in `ucie_coverage.sv` (`ucie_cg` covergroup). Sampled on every RX output flit via `cov.analysis_export`.

```
covergroup ucie_cg

  cp_data_lo: coverpoint flit_data[31:0]          (lower word of flit)
    bins:
      all_zeros  = { 32'h0000_0000 }
      all_ones   = { 32'hFFFF_FFFF }
      low_byte   = { [32'h00000001 : 32'h000000FF] }
      mid_range  = { [32'h00000100 : 32'hFFFEFFFE] }
      other[]    = default

  cp_data_hi: coverpoint flit_data[255:224]       (upper word of flit)
    bins:
      all_zeros  = { 32'h0000_0000 }
      all_ones   = { 32'hFFFF_FFFF }
      non_zero   = { [32'h00000001 : 32'hFFFFFFFE] }

  cp_type: coverpoint flit_type[1:0]
    bins:
      data_flit  = { 2'b00 }
      null_flit  = { 2'b01 }

endgroup
```

**Coverage hits per test:**

| Coverpoint | `ucie_single_flit_test` | `ucie_burst_flit_test` |
|---|---|---|
| `cp_data_lo.all_zeros` | Possible (random) | Guaranteed (flit 0) |
| `cp_data_lo.all_ones` | Possible (random) | Guaranteed (flit 1) |
| `cp_data_lo.mid_range` | Likely (4 random) | High (16 random) |
| `cp_data_hi.all_zeros` | Possible | Guaranteed (flit 0) |
| `cp_data_hi.all_ones` | Possible | Guaranteed (flit 1) |
| `cp_type.data_flit` | Yes (constraint) | Yes (constraint) |

---

## 10. Simulation Commands

### Prerequisites

- Synopsys VCS with UVM 1.2 (`-ntb_opts uvm-1.2`)
- Working directory: `protocols/ucie/sim/`

### Build and Run

```bash
# Compile + run default test (ucie_single_flit_test)
make all

# Compile only
make compile

# Run a specific test
make run TESTNAME=ucie_single_flit_test
make run TESTNAME=ucie_burst_flit_test

# Run regression (both tests)
make regress

# Run with verbosity and custom seed
make run TESTNAME=ucie_burst_flit_test UVM_VERBOSITY=UVM_HIGH SEED=42

# Clean artifacts
make clean
```

### VCS Compile Command (expanded)

```bash
vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2         \
    +incdir+../tb/agent +incdir+../tb/sequences                       \
    +incdir+../tb/env   +incdir+../tb/tests                           \
    +define+UVM_NO_DEPRECATED -l compile.log                          \
    ../rtl/ucie_tx.sv                                                  \
    ../rtl/ucie_rx.sv                                                  \
    ../rtl/ucie_adapter_top.sv                                         \
    ../tb/interface/ucie_if.sv                                         \
    ../tb/agent/ucie_agent_pkg.sv                                      \
    ../tb/top/tb_top.sv                                                \
    -o simv
```

### Simulation Invocation (expanded)

```bash
./simv +UVM_TESTNAME=ucie_burst_flit_test \
       +UVM_VERBOSITY=UVM_LOW             \
       -l sim_ucie_burst_flit_test.log    \
       +ntb_random_seed=1
```

### Expected Log Output (UVM_LOW verbosity)

```
UVM_INFO @ 0: reporter [RNTST] Running test ucie_burst_flit_test...
...
UVM_INFO @ 680ns: uvm_test_top.env.sb [SB] UCIe SB: PASS=18 FAIL=0
UVM_INFO @ 680ns: uvm_test_top.env.sb [SB] TEST PASSED
...
UVM_INFO @ 680ns: reporter [TEST_DONE] UVM-reported: 0 UVM_ERROR
```

### Log Files Generated

| File | Contents |
|---|---|
| `compile.log` | VCS elaboration output |
| `sim_ucie_single_flit_test.log` | Single flit test runtime log |
| `sim_ucie_burst_flit_test.log` | Burst flit test runtime log |

---

## Appendix: DUT Parameter Reference

| Parameter | Value | Notes |
|---|---|---|
| `FLIT_WIDTH` | 256 | Bits per UCIe flit |
| `FIFO_DEPTH` | 8 | TX buffer depth (slots) |
| `CREDIT_W` | 4 | `$clog2(9)` — holds 0..8 |
| `PTR_W` | 3 | `$clog2(8)` — 3-bit pointer for 8-slot FIFO |
| `CLK_PERIOD` | 10 ns | 100 MHz simulation clock |
| `BAUD_RATE` | N/A | Parallel interface, not serial |
| Reset deassert | t=100 ns | After 10 clock cycles |
| Simulation timeout | 1 ms | Hard guard in tb_top |
