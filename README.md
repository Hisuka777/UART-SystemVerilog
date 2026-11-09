# UART Controller in SystemVerilog

A parameterized 8-bit UART controller implemented in SystemVerilog and built with Intel Quartus Prime. The current design contains a transmitter, receiver, baud-rate generator, and a two-flip-flop synchronizer on the asynchronous RX input.

> **Project status:** baseline implementation imported from the existing Quartus project. The saved Questa run completed 8/8 loopback tests successfully. Quartus compilation and fitting also completed successfully for the selected Cyclone V device. Physical-board operation has **not** been demonstrated in the supplied evidence; the fitter report flags missing package-pin assignments.

## Features currently implemented

- UART 8N1 framing: 8 data bits, no parity, 1 stop bit.
- Least-significant-bit-first transmission.
- Separate TX and RX finite-state machines.
- Parameterized top-level clock frequency and baud rate (default: 50 MHz / 115200 baud).
- Baud tick generator shared with the TX state machine.
- Two-flop synchronizer for the asynchronous RX input.
- `tx_busy` and `rx_valid` status outputs.
- Self-checking loopback testbench with eight byte patterns and a timeout.

## Architecture

```text
                    +--------------------+
clk, rst ---------->|   baud_generator   |---- baud_tick ----+
                    +--------------------+                    |
                                                              v
tx_start, tx_data --------------------------------------> +--------+
                                                          | uart_tx|---- tx
                                                          +--------+      |
                                                                          |
                                                                          +---- loopback in testbench
                                                                          |
rx <--------------------------------------------------------------+       |
                                                                   v       |
                                                          +----------------+
                                                          | rx_synchronizer|
                                                          +-------+--------+
                                                                  |
                                                                  v
                                                             +--------+
                                                             | uart_rx|
                                                             +---+----+
                                                                 |
                                                           rx_data, rx_valid
```

### Top-level interface

Module: `UART` (`rtl/UART.sv`)

| Signal | Direction | Description |
|---|---|---|
| `clk` | input | FPGA system clock |
| `rst` | input | Active-high synchronous reset |
| `tx_start` | input | Requests transmission of `tx_data` |
| `tx_data[7:0]` | input | Byte to transmit |
| `tx` | output | UART serial transmit line |
| `tx_busy` | output | High while transmitter is active |
| `rx` | input | UART serial receive line |
| `rx_data[7:0]` | output | Last received byte |
| `rx_valid` | output | Pulses when a byte with a valid stop bit is received |

## Repository layout

```text
UART-SystemVerilog/
├── rtl/
│   ├── UART.sv
│   ├── baud_generator.sv
│   ├── uart_tx.sv
│   ├── uart_rx.sv
│   └── rx_synchronizer.sv
├── tb/
│   └── test_UART.sv
├── sim/
│   └── run_questa.do
├── docs/
│   ├── architecture.md
│   ├── verification.md
│   └── next_steps.md
├── UART.qpf
├── UART.qsf
├── UART.sdc
├── .gitignore
└── README.md
```

## Default configuration

- FPGA family: Intel/Altera Cyclone V
- Quartus device selected in the imported project: `5CGXFC7C7F23C8`
- Clock frequency: 50 MHz
- UART baud rate: 115200
- Calculated clocks per bit: `50,000,000 / 115,200 = 434` (integer division)
- Frame: 1 start bit, 8 data bits, no parity, 1 stop bit

The supplied SDC constrains the `clk` input to a 20 ns period.

## Build with Quartus Prime

1. Open `UART.qpf` in Quartus Prime.
2. Confirm the selected device matches the target FPGA/board.
3. Run **Processing → Start Compilation**.
4. Review Analysis & Synthesis, Fitter, and Timing Analyzer reports.

The QSF references the RTL under `rtl/` and the testbench under `tb/`.

## Simulate with Questa

From the repository root, open Questa/Questa Altera FPGA Starter Edition and run:

```tcl
do sim/run_questa.do
```

The testbench instantiates `UART`, connects TX to RX for loopback, and tests the bytes:

`00`, `FF`, `AA`, `55`, `A5`, `3C`, `81`, `18`.

## Verification evidence in the supplied project

The saved Questa transcript dated **9 November 2026** records:

- All RTL and testbench files compiled with **0 compile errors and 0 compile warnings**.
- **8 tests passed, 0 tests failed**.
- The simulation completed at approximately 690.29 µs.

The saved Quartus reports dated **9 November 2026** record:

- Analysis & Synthesis: Successful.
- Fitter: Successful.
- Device: Cyclone V `5CGXFC7C7F23C8`.
- Logic utilization: 45 ALMs.
- Total registers: 62.
- Timing Analyzer summary: positive setup and hold slack for the constrained 50 MHz clock.

Important qualification: the Fitter report contains a **critical warning** stating that no exact pin locations were assigned for all 23 I/O pins. The supplied project therefore demonstrates successful compilation/fitting, not a completed board-specific pinout or proof of physical FPGA operation. The `.sof` and large generated simulation/database files are intentionally excluded from version control.

See [docs/verification.md](docs/verification.md) for the detailed record and caveats.

## Known limitations and next engineering tasks

This repository is a baseline, not yet a production-quality UART IP block. The next planned improvements are documented in [docs/next_steps.md](docs/next_steps.md). In particular:

1. Make TX start-bit timing independent of the free-running baud-generator phase.
2. Derive the RX counter width from `CLKS_PER_BIT` instead of fixing it at 9 bits.
3. Guard the `$clog2` counter width for edge parameter values.
4. Expand verification beyond loopback byte patterns (independent TX/RX tests, variable idle gaps, framing errors, reset during traffic, and parameter variations).
5. Add proper board pin assignments and perform a physical FPGA test on a known board.

## Learning objectives

This project is intended to demonstrate RTL design and verification fundamentals: synchronous design, FSMs, baud-rate timing, asynchronous input synchronization, simulation, synthesis, implementation, and timing constraints.
