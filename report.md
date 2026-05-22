# UVM Verification Projects — Report

**Date:** 2026-05-22  
**Tool:** VCS (Synopsys) + UVM 1.2  
**Total Files:** 233 across 11 projects  
**Root:** `UVM_projects/`

---

## 1. Project Overview

This workspace contains full UVM verification environments for **7 protocols** and **4 bridges**, organized as self-contained projects, each with its own RTL DUT, layered UVM testbench, and VCS Makefile.

```
UVM_projects/
├── protocols/
│   ├── axi4/
│   ├── axi4_lite/
│   ├── ahb/
│   ├── apb/
│   ├── spi/
│   ├── i2c/
│   └── uart/
└── bridges/
    ├── axi_to_apb/
    ├── axi_to_ahb/
    ├── ahb_to_apb/
    └── spi_to_i2c/
```

---

## 2. Protocol Projects

### 2.1 AXI4 — `protocols/axi4/`

| Item | Detail |
|------|--------|
| **DUT** | `axi4_slave.sv` — 16-word (32-bit) register file; supports single and INCR burst |
| **Interface** | `axi4_if.sv` — full AW/W/B/AR/R channels; clocking blocks for driver & monitor |
| **Seq Item** | `axi4_seq_item.sv` — op, addr, data[], len, size, burst, id, resp; constraints for 4-byte alignment and consistent burst data array size |
| **Driver** | Drives AW+W channels concurrently, waits for B/R handshake, samples resp |
| **Monitor** | Two parallel threads — collects write (AW→W→B) and read (AR→R) transactions |
| **Scoreboard** | Reference memory model; checks read-back against written values |
| **Coverage** | op × burst, op × len, resp bins |
| **Tests** | `axi4_write_test`, `axi4_read_test`, `axi4_burst_test` |

**Files (21):**
```
rtl/axi4_slave.sv
tb/interface/axi4_if.sv
tb/agent/axi4_seq_item.sv  axi4_sequencer.sv  axi4_driver.sv
         axi4_monitor.sv   axi4_agent.sv       axi4_agent_pkg.sv
tb/sequences/axi4_base_seq.sv  axi4_write_seq.sv  axi4_read_seq.sv  axi4_burst_seq.sv
tb/env/axi4_scoreboard.sv  axi4_coverage.sv  axi4_env.sv
tb/tests/axi4_base_test.sv  axi4_write_test.sv  axi4_read_test.sv  axi4_burst_test.sv
tb/top/tb_top.sv
sim/Makefile
```

---

### 2.2 AXI4-Lite — `protocols/axi4_lite/`

| Item | Detail |
|------|--------|
| **DUT** | `axi4_lite_slave.sv` — 8-word register file; no burst, no ID signals |
| **Interface** | `axi4_lite_if.sv` — AW/W/B/AR/R (single beat only) |
| **Seq Item** | `axi4_lite_seq_item.sv` — op, addr, data, strb, resp |
| **Driver** | AW and W channels driven in parallel `fork/join`, then waits B/R |
| **Scoreboard** | Byte-enable aware reference memory; read-back check |
| **Tests** | `axi4_lite_write_test`, `axi4_lite_read_test` |

**Files (19):** same layer structure as AXI4 minus burst sequence and test.

---

### 2.3 AHB — `protocols/ahb/`

| Item | Detail |
|------|--------|
| **DUT** | `ahb_slave.sv` — 16-word memory; HTRANS IDLE/NONSEQ/SEQ; HREADY handshake |
| **Interface** | `ahb_if.sv` — HADDR, HTRANS, HWRITE, HSIZE, HBURST, HWDATA, HRDATA, HREADY, HRESP, HSEL |
| **Driver** | Address phase → data phase model; handles multiple beats for INCR4 |
| **Scoreboard** | Reference memory; read-after-write check per beat |
| **Coverage** | op × burst (SINGLE/INCR/INCR4), size bins |
| **Tests** | `ahb_single_test`, `ahb_burst_test` |

**Files (19).**

---

### 2.4 APB — `protocols/apb/`

| Item | Detail |
|------|--------|
| **DUT** | `apb_slave.sv` — 8-register file; SETUP→ENABLE state machine; inserts 1 wait state (PREADY held low); PSLVERR on out-of-range address |
| **Interface** | `apb_if.sv` — PADDR, PSEL, PENABLE, PWRITE, PWDATA, PRDATA, PREADY, PSLVERR |
| **Driver** | SETUP→ENABLE→PREADY poll; captures PRDATA and PSLVERR |
| **Scoreboard** | Skips PSLVERR transactions; reference memory for valid range |
| **Coverage** | op × PSLVERR cross; addr register bins |
| **Tests** | `apb_write_test`, `apb_read_test` |

**Files (19).**

---

### 2.5 SPI — `protocols/spi/`

| Item | Detail |
|------|--------|
| **DUT** | `spi_slave.sv` — SPI Mode 0 (CPOL=0, CPHA=0); 8 registers; frame = addr byte (bit7=R/W, bits[6:0]=addr) + data bytes |
| **Interface** | `spi_if.sv` — SCLK, CS_N, MOSI, MISO |
| **Driver** | Bit-bangs SCLK/MOSI; samples MISO on rising SCLK; CS_N framing |
| **Scoreboard** | Reference register file; read-back check per byte |
| **Coverage** | op × transfer length |
| **Tests** | `spi_single_test` (1 byte), `spi_multi_test` (2-4 bytes) |

**Files (19).**

---

### 2.6 I2C — `protocols/i2c/`

| Item | Detail |
|------|--------|
| **DUT** | `i2c_slave.sv` — 7-bit addressing (addr 0x50); 8 registers; START/STOP detection; ACK/NACK; sequential read with repeated START |
| **Interface** | `i2c_if.sv` — SCL, SDA (bidirectional wire with tri-state); pull-up in tb_top |
| **Driver** | Generates START, address byte, register address, data bytes, STOP; repeated-START for reads |
| **Scoreboard** | Reference register file; NACK logging |
| **Coverage** | op × byte count |
| **Tests** | `i2c_write_test`, `i2c_read_test` |

**Files (19).**

---

### 2.7 UART — `protocols/uart/`

| Item | Detail |
|------|--------|
| **DUT** | `uart_tx.sv` + `uart_rx.sv` + `uart_top.sv` — 8N1 format; CLK_FREQ=50 MHz, BAUD_RATE=115200; TX feeds RX in loopback |
| **Interface** | `uart_if.sv` — tx, rx, tx_data[7:0], tx_valid, tx_ready, rx_data[7:0], rx_valid |
| **Driver** | Waits for tx_ready; drives tx_data/tx_valid; waits for completion |
| **Monitor** | Samples rx_valid; publishes received byte |
| **Scoreboard** | Queue-based; driver pre-queues expected bytes; monitor matches against them |
| **Coverage** | Data value bins: 0x00, 0xFF, printable ASCII, other |
| **Tests** | `uart_single_test` (4 random bytes), `uart_multi_test` ("Hello World!\n" + 16 random bytes) |

**Files (21):** includes 3 RTL files.

---

## 3. Bridge Projects

All bridges use a **dual-agent** pattern:
- **Master agent** — active (driver + monitor), drives the master-side protocol
- **Slave agent** — passive (monitor only, `UVM_PASSIVE`), observes the slave-side protocol
- **Scoreboard** — two analysis imports (`master_imp`, `slave_imp`); matches transactions by address and data

---

### 3.1 AXI-to-APB Bridge — `bridges/axi_to_apb/`

| Item | Detail |
|------|--------|
| **DUT** | `axi_to_apb_bridge.sv` — AXI4-Lite slave port → APB master port |
| **State machine** | IDLE → AXI_LATCH → APB_SETUP → APB_ENABLE → WR/RD_RESPOND |
| **Master agent** | AXI4-Lite active agent (drives AWADDR, WDATA, ARADDR; reads RDATA, BRESP) |
| **Slave agent** | APB passive monitor (captures PADDR, PWDATA/PRDATA on PREADY) |
| **Scoreboard** | Matches AXI addr/data/op against APB addr/data/op; checks PSLVERR→SLVERR propagation |
| **Memory model** | In-TB APB memory (responds to bridge APB port) |
| **Tests** | `bridge_write_test` (8 random writes), `bridge_read_test` (4 writes then 4 reads) |

**Files (24).**

---

### 3.2 AXI-to-AHB Bridge — `bridges/axi_to_ahb/`

| Item | Detail |
|------|--------|
| **DUT** | `axi_to_ahb_bridge.sv` — AXI4-Lite slave → AHB master (NONSEQ only) |
| **State machine** | IDLE → AXI_LATCH → AHB_ADDR → AHB_DATA → WR/RD_RESPOND |
| **Master agent** | AXI4-Lite active agent |
| **Slave agent** | AHB passive monitor (captures address phase + data phase) |
| **Scoreboard** | Matches AXI addr/data against AHB addr/data |
| **Memory model** | In-TB AHB memory (HREADY=1 always) |
| **Tests** | `bridge_write_test`, `bridge_read_test` |

**Files (24).**

---

### 3.3 AHB-to-APB Bridge — `bridges/ahb_to_apb/`

| Item | Detail |
|------|--------|
| **DUT** | `ahb_to_apb_bridge.sv` — AHB-Lite slave (HSEL/HTRANS) → APB master |
| **State machine** | IDLE → AHB_SAMPLE → APB_SETUP → APB_ENABLE → IDLE |
| **Behavior** | HREADY_OUT held low during APB access; HRESP = PSLVERR |
| **Master agent** | AHB active agent; drives HADDR/HTRANS/HWRITE; waits HREADY_OUT |
| **Slave agent** | APB passive monitor |
| **Scoreboard** | Matches AHB addr/data against APB addr/data |
| **Tests** | `bridge_write_test`, `bridge_read_test` |

**Files (24).**

---

### 3.4 SPI-to-I2C Bridge — `bridges/spi_to_i2c/`

| Item | Detail |
|------|--------|
| **DUT** | `spi_to_i2c_bridge.sv` — 16-bit SPI frame → I2C master transaction |
| **Frame format** | bit[15]=R/W, bits[14:8]=I2C 7-bit addr, bits[7:0]=data |
| **I2C generation** | SCL = SCLK/CLK_DIV; generates START, addr+R/W, ACK, data, STOP |
| **Master agent** | SPI active agent; bit-bangs 2-byte frame |
| **Slave agent** | I2C passive monitor; detects START, captures addr byte + data byte |
| **Scoreboard** | Matches SPI {i2c_addr, op, data} against I2C {slave_addr, op, data} |
| **Tests** | `bridge_write_test` (4 random writes), `bridge_read_test` (2 writes + 2 reads) |

**Files (24).**

---

## 4. UVM Layer Architecture

Every project follows the standard UVM 1.2 layered architecture:

```
┌─────────────────────────────────────────┐
│              UVM Test                   │  ← run_phase() starts sequences
├─────────────────────────────────────────┤
│              UVM Env                    │  ← build_phase() + connect_phase()
│  ┌──────────────┐  ┌───────────────┐    │
│  │  UVM Agent   │  │  Scoreboard   │    │
│  │  ┌────────┐  │  │  (ref model)  │    │
│  │  │ Driver │  │  ├───────────────┤    │
│  │  ├────────┤  │  │   Coverage    │    │
│  │  │Monitor ├──┼──►  (covergroup) │    │
│  │  ├────────┤  │  └───────────────┘    │
│  │  │Sequencer│ │                       │
│  └──────────────┘                       │
├─────────────────────────────────────────┤
│         SystemVerilog Interface         │  ← clocking blocks
├─────────────────────────────────────────┤
│               DUT (RTL)                 │
└─────────────────────────────────────────┘
```

**Key UVM features used:**
- `uvm_component_utils` / `uvm_object_utils` registration macros
- `uvm_info`, `uvm_error`, `uvm_fatal` messaging
- Phase methods: `build_phase`, `connect_phase`, `run_phase`, `report_phase`
- TLM analysis ports: `uvm_analysis_port`, `uvm_analysis_imp`, `uvm_analysis_imp_master/slave`
- Factory overrides via `type_id::create()`
- `uvm_config_db` for virtual interface passing
- `UVM_PASSIVE` agent mode for slave-side monitors in bridge projects
- Sequence layering: `start_item` / `finish_item` / `randomize() with {}`
- Covergroups with cross coverage

---

## 5. File Count Summary

| Project | Files |
|---------|------:|
| protocols/axi4 | 21 |
| protocols/axi4_lite | 19 |
| protocols/ahb | 19 |
| protocols/apb | 19 |
| protocols/spi | 19 |
| protocols/i2c | 19 |
| protocols/uart | 21 |
| bridges/axi_to_apb | 24 |
| bridges/axi_to_ahb | 24 |
| bridges/ahb_to_apb | 24 |
| bridges/spi_to_i2c | 24 |
| **Total** | **233** |

---

## 6. Execution Steps

See `EXECUTION_STEPS.md` for step-by-step simulation instructions.
