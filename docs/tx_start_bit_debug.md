# UART TX start-bit phase defect — diagnosis and verification record

## Status

- **Baseline observation:** reproduced in user's Questa Altera Starter FPGA Edition 2025.2 run, 12 November 2026.
- **RTL correction:** pending.
- **Post-fix simulation:** not yet run.
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

## Proposed minimal RTL correction

Preserve the shared baud generator and add a `WAIT_BAUD` state between `IDLE` and `START`:

1. In `IDLE`, on accepted `tx_start`, latch data, set busy, and enter `WAIT_BAUD`; leave `tx` HIGH.
2. In `WAIT_BAUD`, hold `tx` HIGH until `baud_tick`. On the tick, enter `START` (do **not** drive TX LOW in this state if the existing `START` state already owns the output).
3. In `START`, drive `tx` LOW, and on the **next** `baud_tick`, enter `DATA`.
4. Subsequent data and stop-bit transitions continue on baud ticks. With registered outputs, verify the actual TX edge-to-edge width in simulation; avoid changing the output from two different states in a way that introduces a one-cycle shift.
5. Document that this shared-divider approach adds up to almost one bit period of start latency after request acceptance. A transmitter-local divider offers a different latency tradeoff.

**Do not mark complete on code inspection alone:** rerun the phase test and capture measured intervals.

## Acceptance criteria

- Every checked phase (ideally all 434) yields a 434-cycle start LOW pulse.
- `tx_data` is latched at accepted `tx_start` and sent D0-first; include an asymmetric pattern such as `8'h53`.
- Verify all eight data-bit intervals and a complete stop-bit interval, not just the first LOW pulse.
- Verify `tx_busy`, reset behavior and re-requests while busy.
- Existing UART loopback regression remains passing.
- Build outputs, timestamped simulator log and at least one annotated waveform are retained as evidence. Do not commit generated simulator libraries (`work/`, `rtl_work/`) or WLF files.

## Recommended Git history

1. `test(uart): reproduce TX start-bit timing defect` — phase test and this diagnosis; include raw transcript in `docs/evidence/` if available.
2. `fix(uart-tx): align start bit to baud tick` — only after source correction and verification; update this document with actual post-fix results.

## Limitations

This document records test output supplied by the project author. It is not a substitute for raw Questa logs, review of the full repository revision, or on-board verification.
