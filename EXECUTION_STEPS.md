# UVM Projects — Execution Steps

**Simulator:** Synopsys VCS with UVM 1.2  
**Shell:** tcsh / bash

---

## Prerequisites

```bash
# Verify VCS is in PATH
which vcs
vcs -version

# Verify UVM 1.2 is available
ls $VCS_HOME/etc/uvm-1.2/

# Set environment (adjust paths to your installation)
setenv VCS_HOME  /tools/synopsys/vcs/latest      # tcsh
setenv UVM_HOME  $VCS_HOME/etc/uvm-1.2
```

> **Questa / Xcelium users:** Replace the VCS compile command in each Makefile with the equivalent for your simulator (see Section 4).

---

## 1. Quick Start — Single Test

### Step 1: Navigate to the sim directory of any project

```bash
cd /home/radharma/Documents/UVM_Projects/UVM_projects/protocols/axi4/sim
```

### Step 2: Compile

```bash
make compile
```

This runs:
```bash
vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2 \
    +incdir+../tb/agent +incdir+../tb/sequences \
    +incdir+../tb/env   +incdir+../tb/tests     \
    +define+UVM_NO_DEPRECATED                   \
    ../rtl/axi4_slave.sv                        \
    ../tb/interface/axi4_if.sv                  \
    ../tb/agent/axi4_agent_pkg.sv               \
    ../tb/top/tb_top.sv                         \
    -o simv -l compile.log
```

### Step 3: Run a test

```bash
make run TESTNAME=axi4_write_test
```

This runs:
```bash
./simv +UVM_TESTNAME=axi4_write_test +UVM_VERBOSITY=UVM_LOW \
       -l sim_axi4_write_test.log +ntb_random_seed=1
```

### Step 4: Run full regression

```bash
make regress
```

Runs all tests sequentially and produces per-test log files.

---

## 2. All Protocol Projects

### AXI4

```bash
cd protocols/axi4/sim
make compile
make run TESTNAME=axi4_write_test          # 16 random single writes
make run TESTNAME=axi4_read_test           # 8 writes then 8 reads (scoreboard checks)
make run TESTNAME=axi4_burst_test          # 4-beat INCR bursts + readback
make regress                               # runs all three
```

### AXI4-Lite

```bash
cd protocols/axi4_lite/sim
make compile
make run TESTNAME=axi4_lite_write_test     # 8 random writes
make run TESTNAME=axi4_lite_read_test      # 8 writes + 8 reads
make regress
```

### AHB

```bash
cd protocols/ahb/sim
make compile
make run TESTNAME=ahb_single_test          # 16 SINGLE transfers (random R/W)
make run TESTNAME=ahb_burst_test           # 4 INCR4 write bursts + INCR4 readback
make regress
```

### APB

```bash
cd protocols/apb/sim
make compile
make run TESTNAME=apb_write_test           # 8 random register writes (valid range)
make run TESTNAME=apb_read_test            # 8 writes + 8 reads (scoreboard checks)
make regress
```

### SPI

```bash
cd protocols/spi/sim
make compile
make run TESTNAME=spi_single_test          # 8 single-byte write/read transactions
make run TESTNAME=spi_multi_test           # 4 multi-byte (2-4 bytes) write bursts
make regress
```

### I2C

```bash
cd protocols/i2c/sim
make compile
make run TESTNAME=i2c_write_test           # 4 single-byte register writes
make run TESTNAME=i2c_read_test            # 4 writes then 4 reads (repeated START)
make regress
```

### UART

```bash
cd protocols/uart/sim
make compile
make run TESTNAME=uart_single_test         # 4 random bytes (TX→RX loopback)
make run TESTNAME=uart_multi_test          # "Hello World!\n" + 16 random bytes
make regress
```

> **Note:** UART simulation time is longer due to baud-rate timing (50 MHz clock, 115200 baud = ~434 clock cycles per bit).

---

## 3. All Bridge Projects

### AXI-to-APB Bridge

```bash
cd bridges/axi_to_apb/sim
make compile
make run TESTNAME=bridge_write_test        # 8 AXI writes → APB writes (dual-agent scoreboard)
make run TESTNAME=bridge_read_test         # 4 writes + 4 reads through bridge
make regress
```

### AXI-to-AHB Bridge

```bash
cd bridges/axi_to_ahb/sim
make compile
make run TESTNAME=bridge_write_test
make run TESTNAME=bridge_read_test
make regress
```

### AHB-to-APB Bridge

```bash
cd bridges/ahb_to_apb/sim
make compile
make run TESTNAME=bridge_write_test        # AHB NONSEQ → APB SETUP+ENABLE
make run TESTNAME=bridge_read_test
make regress
```

### SPI-to-I2C Bridge

```bash
cd bridges/spi_to_i2c/sim
make compile
make run TESTNAME=bridge_write_test        # SPI 16-bit frame → I2C write transaction
make run TESTNAME=bridge_read_test
make regress
```

---

## 4. Makefile Variables

Each `sim/Makefile` exposes these variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `TESTNAME` | project-specific | UVM test class name to run |
| `UVM_VERBOSITY` | `UVM_LOW` | UVM message verbosity level |
| `SEED` | `1` | Random seed for `+ntb_random_seed` |

Override any variable on the command line:

```bash
make run TESTNAME=axi4_burst_test UVM_VERBOSITY=UVM_HIGH SEED=42
```

---

## 5. Viewing Waveforms

Add `-debug_all` to VCS flags and use DVE or Verdi:

```bash
# Recompile with debug
vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2 \
    +incdir+../tb/agent +incdir+../tb/sequences \
    +incdir+../tb/env   +incdir+../tb/tests     \
    -debug_all                                  \
    ../rtl/axi4_slave.sv                        \
    ../tb/interface/axi4_if.sv                  \
    ../tb/agent/axi4_agent_pkg.sv               \
    ../tb/top/tb_top.sv -o simv

# Run and dump VPD
./simv +UVM_TESTNAME=axi4_write_test -vpd_file waves.vpd

# Open in DVE
dve -vpd waves.vpd &

# Or open in Verdi
verdi -vpd waves.vpd &
```

The `wave` Makefile target in each project wraps these steps:

```bash
make wave TESTNAME=axi4_write_test
```

---

## 6. Adjusting UVM Verbosity

| Level | What you see |
|-------|-------------|
| `UVM_NONE` | Fatal only |
| `UVM_LOW` | Scoreboard PASS/FAIL summary (default) |
| `UVM_MEDIUM` | Sequence start/finish messages |
| `UVM_HIGH` | Per-transaction driver/monitor prints |
| `UVM_FULL` | All internal UVM messages |

```bash
make run TESTNAME=axi4_write_test UVM_VERBOSITY=UVM_HIGH
```

---

## 7. Simulator-Specific Compile Commands

### Questa (Mentor / Siemens)

```bash
# Compile
vlog -sv -mfcu +incdir+../tb/agent +incdir+../tb/sequences \
     +incdir+../tb/env +incdir+../tb/tests                  \
     +define+UVM_NO_DEPRECATED                               \
     -L $QUESTA_UVM_HOME/verilog_src/uvm-1.2                \
     ../rtl/axi4_slave.sv                                    \
     ../tb/interface/axi4_if.sv                              \
     ../tb/agent/axi4_agent_pkg.sv                           \
     ../tb/top/tb_top.sv

# Simulate
vsim -sv_seed 1 -do "run -all" \
     +UVM_TESTNAME=axi4_write_test +UVM_VERBOSITY=UVM_LOW \
     work.tb_top
```

### Xcelium (Cadence)

```bash
# Compile + elaborate + simulate (single step)
xrun -sv -uvm -uvmhome CDNS-1.2 \
     +incdir+../tb/agent +incdir+../tb/sequences \
     +incdir+../tb/env   +incdir+../tb/tests     \
     ../rtl/axi4_slave.sv                        \
     ../tb/interface/axi4_if.sv                  \
     ../tb/agent/axi4_agent_pkg.sv               \
     ../tb/top/tb_top.sv                         \
     +UVM_TESTNAME=axi4_write_test               \
     +UVM_VERBOSITY=UVM_LOW
```

---

## 8. Running All Projects in Sequence (Batch Regression)

Run this script from `UVM_projects/` to compile and regress every project:

```bash
#!/bin/tcsh
# full_regression.csh

set PROJECTS = ( \
  protocols/axi4     \
  protocols/axi4_lite \
  protocols/ahb      \
  protocols/apb      \
  protocols/spi      \
  protocols/i2c      \
  protocols/uart     \
  bridges/axi_to_apb \
  bridges/axi_to_ahb \
  bridges/ahb_to_apb \
  bridges/spi_to_i2c \
)

set PASS = 0
set FAIL = 0

foreach proj ($PROJECTS)
  echo ""
  echo "=========================================="
  echo " Running: $proj"
  echo "=========================================="
  cd $proj/sim
  make regress
  if ($status == 0) then
    echo "PASS: $proj"
    @ PASS++
  else
    echo "FAIL: $proj"
    @ FAIL++
  endif
  cd -
end

echo ""
echo "=========================================="
echo " REGRESSION COMPLETE"
echo " PASS: $PASS / $FAIL: $FAIL"
echo "=========================================="
```

Save as `full_regression.csh`, then:

```bash
chmod +x full_regression.csh
./full_regression.csh |& tee regression_$(date +%Y%m%d_%H%M%S).log
```

---

## 9. Checking Results

### PASS indicators in the log

```
UVM_INFO @ ...  [SB] TEST PASSED
UVM_INFO @ ...  [SB] Scoreboard: PASS=16 FAIL=0
```

### FAIL indicators in the log

```
UVM_ERROR @ ... [SB] READ MISMATCH addr=0x0000000c exp=0xdeadbeef got=0x00000000
UVM_ERROR @ ... [SB] TEST FAILED: scoreboard mismatches detected
** FATAL ** : $finish called from file "tb_top.sv", line XX
```

### Checking UVM error counts

```bash
grep -E "UVM_ERROR|UVM_FATAL|TEST PASSED|TEST FAILED" sim_*.log
```

---

## 10. Clean Up

```bash
# Clean one project
cd protocols/axi4/sim
make clean

# Clean all projects from root
for d in protocols/*/sim bridges/*/sim; do
  (cd $d && make clean)
done
```

---

## 11. Project Directory Reference

```
UVM_projects/
├── report.md                        ← this report
├── EXECUTION_STEPS.md               ← this file
├── protocols/
│   ├── axi4/
│   │   ├── rtl/axi4_slave.sv
│   │   ├── tb/
│   │   │   ├── interface/axi4_if.sv
│   │   │   ├── agent/               (seq_item, sequencer, driver, monitor, agent, pkg)
│   │   │   ├── sequences/           (base, write, read, burst)
│   │   │   ├── env/                 (scoreboard, coverage, env)
│   │   │   ├── tests/               (base, write, read, burst)
│   │   │   └── top/tb_top.sv
│   │   └── sim/Makefile
│   ├── axi4_lite/  (same structure)
│   ├── ahb/        (same structure)
│   ├── apb/        (same structure)
│   ├── spi/        (same structure)
│   ├── i2c/        (same structure)
│   └── uart/
│       ├── rtl/uart_tx.sv  uart_rx.sv  uart_top.sv
│       └── ...
└── bridges/
    ├── axi_to_apb/
    │   ├── rtl/axi_to_apb_bridge.sv
    │   ├── tb/
    │   │   ├── interface/           (axi_lite_if.sv, apb_if.sv)
    │   │   ├── master_agent/        (AXI4-Lite active agent)
    │   │   ├── slave_agent/         (APB passive monitor)
    │   │   ├── sequences/           (base, write, read)
    │   │   ├── env/                 (dual-port scoreboard, coverage, env)
    │   │   ├── tests/               (base, write, read)
    │   │   └── top/tb_top.sv
    │   └── sim/Makefile
    ├── axi_to_ahb/ (AXI4-Lite master → AHB passive monitor)
    ├── ahb_to_apb/ (AHB master → APB passive monitor)
    └── spi_to_i2c/ (SPI master → I2C passive monitor)
```
