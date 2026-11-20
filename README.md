# UART Controller in SystemVerilog

A parameterized 8-bit UART controller implemented in SystemVerilog and built with Intel Quartus Prime. The current design contains a transmitter, receiver, baud-rate generator, and a two-flip-flop synchronizer on the asynchronous RX input.

> **Project status (development branch):** transmitter phase-alignment correction passed 434/434 start-bit tests, plus 5/5 full-frame midpoint checks and 9/9 measured visible transitions in the author's Questa 2025.2 runs on 19 November 2026. The previous baseline recorded 8/8 loopback tests and Quartus compilation/fitting; these **have not yet been rerun after the TX correction**. FPGA hardware operation has not been established; package-pin assignments remain outstanding.

## Features currently implemented

- UART 8N1 framing: 8 data bits, no parity, 1 stop bit.
- Least-significant-bit-first transmission.
- Separate TX and RX finite-state machines, including a TX WAIT_BAUD alignment state on this development branch.
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
│   ├── test_UART.sv
│   ├── test_uart_tx.sv
│   ├── test_uart_tx_frame.sv
│   └── test_uart_tx_handshake.sv
├── sim/
│   └── run_questa.do
├── docs/
│   ├── architecture.md
│   ├── verification.md
│   ├── next_steps.md
│   ├── tx_start_bit_debug.md
│   └── learning_uart_tx_timing.md
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

## Transmitter development milestone — test, fix, verify

A six-phase diagnostic first exposed a **variable-length start bit** (1/6 passed), caused by starting TX without aligning to the free-running baud generator. The correction adds `STATE_WAIT_BAUD` before `STATE_START`, keeping TX HIGH until the next baud boundary.

**Questa 2025.2 results supplied by the project author (19-20 November 2026):**

| Regression | Observed |
|---|---:|
| Start-bit duration across phase offsets 0–433 | **434 passed, 0 failed** |
| Complete 8N1 midpoint sequence (`55`, `AA`, `53`, `00`, `FF`) | **5 passed** |
| Visible edge intervals for `8'h55` | **9 passed** |
| Example start-bit width from waveform cursors | **8,680,000 ps = 434 clocks** |
| Busy handshake: complete frames | **2 passed (`53`, `A6`)** |
| Busy-request rejection | **1 passed (`F0` ignored)** |
| STOP-to-ready timing | **433 clocks observed and checked** |
| Post-fix TX/RX loopback | **8 passed, 0 failed** |

These results verify the exercised TX timing, full-frame samples, selected busy/ready scenarios, and eight corrected TX/RX loopback bytes. They do **not** establish reset-during-frame behavior, all legal request sequences, RX robustness, or physical FPGA operation. See [`tb/test_uart_tx_handshake.sv`](tb/test_uart_tx_handshake.sv) for the observed busy-rejection and consecutive-frame regression.

**Hands-on visual guide:** [UART TX illustrated lab notebook (PDF)](docs/guides/UART_TX_Hands_On_Lab_Guide.pdf) - revised for the 20 Nov handshake and loopback results (revision v2 is provided for local Git upload). **Learning notes:** [TX timing and FSM walkthrough](docs/learning_uart_tx_timing.md). **Evidence index:** [Questa results and waveform captures](docs/evidence/README.md). **Engineering diagnosis:** [Start-bit defect report](docs/tx_start_bit_debug.md).

From the repository root, run the independent TX frame test in Questa:

```tcl
vlib work_frame
vlog -work work_frame -sv rtl/baud_generator.sv
vlog -work work_frame -sv rtl/uart_tx.sv
vlog -work work_frame -sv tb/test_uart_tx_frame.sv
vsim -t 1ps -voptargs=+acc work_frame.test_uart_tx_frame
run -all
```

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

1. **Verified in author-supplied Questa runs on development branch:** TX phase timing, complete TX frames, selected handshake scenarios, and 8/8 post-fix TX/RX loopback. Review testbench posedge stimulus scheduling and reset scenarios before merging.
2. Derive the RX counter width from `CLKS_PER_BIT` instead of fixing it at 9 bits.
3. Guard the `$clog2` counter width for edge parameter values.
4. Expand verification beyond loopback byte patterns (independent TX/RX tests, variable idle gaps, framing errors, reset during traffic, and parameter variations).
5. Add proper board pin assignments and perform a physical FPGA test on a known board.

## Learning objectives

This project is intended to demonstrate RTL design and verification fundamentals: synchronous design, FSMs, baud-rate timing, asynchronous input synchronization, simulation, synthesis, implementation, and timing constraints.
