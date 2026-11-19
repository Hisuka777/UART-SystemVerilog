# UART TX start-bit phase defect — diagnosis and verification record

## Status

- **Baseline observation:** reproduced in user's Questa Altera Starter FPGA Edition 2025.2 run, 12 November 2026.
- **RTL correction:** implemented on branch `fix/uart-tx-start-bit-alignment`; start-bit timing regression passed in author's Questa run.
- **Post-fix simulation:** on 19 November 2026, the author reported **434 passed, 0 failed** for phase offsets 0–433 in Questa Altera Starter FPGA Edition 2025.2. A waveform screenshot showed a LOW pulse from 26,250,000 ps to 34,930,000 ps (434 system clocks).
- **Physical hardware validation:** not established.

## Configuration

- System clock: 50 MHz (20 ns period)
- Nominal baud rate: 115200
- Integer divider: `CLKS_PER_BIT = 434`
- Ideal start-bit duration at configured divider: 434 clocks = 8,680,000 ps (8.68 us)
- Actual divided baud: 50,000,000/434 = approximately 115207.37 baud

## Failure mechanism

The transmitter accepts `tx_start` independently of the free-running baud generator's phase and then advances from the START state on the next `baud_tick`. This means the first start-bit interval can be shorter than a full bit period. Subsequent data-bit intervals may still be spaced by full baud periods; a loopback-only test may therefore fail to expose the initial framing issue.

`tx_data` is a parallel input bus; serial output is `tx`. The 0xFF payload was intentionally used for measuring the start-bit LOW pulse: D0 is HIGH, producing a rising edge at the end of the start bit. This does **not** independently verify data ordering.

## Baseline simulation evidence

The following data is transcribed from the user's Questa Transcript; it has not been independently rerun in this workspace.

| phase_offset (clk cycles) | measured start bit (clk cycles) | expected | outcome |
|---:|---:|---:|---|
| 0 | 434 | 434 | PASS |
| 1 | 433 | 434 | FAIL |
| 108 | 326 | 434 | FAIL |
| 217 | 217 | 434 | FAIL |
| 324 | 110 | 434 | FAIL |
| 432 | 2 | 434 | FAIL |

**Summary:** 1 pass, 5 fails (diagnostic test is expected to fail on the baseline).

In the first trial, TX falls at 110,000 ps and rises at 8,790,000 ps: 8,680,000 ps / 20,000 ps per clock = 434 cycles. In the second trial, the start-bit pulse measures 433 cycles.

## RTL correction and phase-test verification

Preserve the shared baud generator and add a `WAIT_BAUD` state between `IDLE` and `START`:

1. In `IDLE`, on accepted `tx_start`, latch data, set busy, and enter `WAIT_BAUD`; leave `tx` HIGH.
2. In `WAIT_BAUD`, hold `tx` HIGH until `baud_tick`. On the tick, enter `START` (do **not** drive TX LOW in this state if the existing `START` state already owns the output).
3. In `START`, drive `tx` LOW, and on the **next** `baud_tick`, enter `DATA`.
4. Subsequent data and stop-bit transitions continue on baud ticks. With registered outputs, verify the actual TX edge-to-edge width in simulation; avoid changing the output from two different states in a way that introduces a one-cycle shift.
5. Document that this shared-divider approach adds up to almost one bit period of start latency after request acceptance. A transmitter-local divider offers a different latency tradeoff.

**Phase timing has been confirmed in the user's Questa run.** This does not yet demonstrate complete frame-level correctness, loopback regression, Quartus timing closure, or FPGA operation.

### Updated verification procedure

- On the fix branch, `tb/test_uart_tx.sv` sweeps **all 434** initial phase offsets.
- The start-bit watchdog permits the initial alignment latency **plus** a full start-bit period.
- The existing test measures only the start-bit LOW pulse with `8'hFF`; it does **not** prove full-frame timing or LSB-first data ordering.
- Phase-test evidence received from the author: **434/434 passed**, 0 failures (Questa Transcript), with an 8,680,000 ps start-bit waveform measurement.
- A new independent `tb/test_uart_tx_frame.sv` checks midpoint values for 5 full 8N1 frames (`55`, `AA`, `53`, `00`, `FF`), checks captured data despite an input-bus change, checks busy at frame start/end, and checks nine consecutive output-edge intervals for `0x55`. **New test has not yet been executed.**
- Run the existing UART loopback regression afterward; then extend verification of reset and re-requests while busy.


## Running the independent TX frame regression in Questa

From the repository root, using a separate simulation library:

```tcl
vlib work_frame
vlog -work work_frame -sv rtl/baud_generator.sv
vlog -work work_frame -sv rtl/uart_tx.sv
vlog -work work_frame -sv tb/test_uart_tx_frame.sv
vsim -t 1ps -voptargs=+acc work_frame.test_uart_tx_frame
add wave -r sim:/test_uart_tx_frame/*
run -all
```

Expected (not yet confirmed) summary: `TX FRAME SUMMARY: 5 frames passed, 9 edge intervals passed`.

This test checks all 10 midpoint values of 8N1 frames and measures all nine **visible** value-change boundaries of a `0x55` frame. It does not itself measure a full stop interval on the serial line, because the line stays HIGH after STOP into IDLE. A separate busy/ready handshake test is advisable.

## Acceptance criteria

- [PASS, Questa author run] Every phase offset 0–433 yields a 434-cycle start LOW pulse.
- [PENDING independent test] `tx_data` is latched at accepted `tx_start` and sent D0-first; verify `8'h53` and alternating patterns.
- [PENDING independent test] Verify the frame data and nine visible edge intervals using the `0x55` pattern, then check stop/ready handshake.
- Verify `tx_busy`, reset behavior and re-requests while busy.
- Existing UART loopback regression remains passing.
- Build outputs, timestamped simulator log and at least one annotated waveform are retained as evidence. Do not commit generated simulator libraries (`work/`, `rtl_work/`) or WLF files.

## Recommended Git history

1. `test(uart): reproduce TX start-bit timing defect` — phase test and this diagnosis; include raw transcript in `docs/evidence/` if available.
2. `fix(uart-tx): align start bit to baud tick` — proposed on development branch with phase test verified; complete independent frame and integration regression before merging.

## Limitations

This document records test output supplied by the project author. It is not a substitute for raw Questa logs, review of the full repository revision, or on-board verification.
