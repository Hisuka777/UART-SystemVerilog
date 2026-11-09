# Next Steps / Engineering Backlog

The following are code-review findings and planned improvements from inspecting the baseline RTL. They are not claimed as completed features.

## Priority 1 — protocol correctness and parameter safety

- [ ] Rework TX baud timing so the start bit always lasts one complete bit period regardless of the phase of the free-running baud tick when `tx_start` is accepted. Consider a TX-local baud counter or frame-start phase alignment.
- [ ] Add tests that launch frames at different idle gaps to expose start-bit phase dependence.
- [ ] Replace the fixed `logic [8:0] rx_counter` with a width derived from `CLKS_PER_BIT`.
- [ ] Make the baud counter width safe when `$clog2(CLKS_PER_BIT)` evaluates to zero (for example, use a minimum width of one).
- [ ] Add parameter checks for legal clock/baud combinations and ensure the calculated divisor is valid.

## Priority 2 — protocol and interface robustness

- [ ] Add a framing-error output/status when the stop bit is low.
- [ ] Define and document behavior for `tx_start` asserted while `tx_busy` is high.
- [ ] Consider a `tx_ready` or accepted-start handshake.
- [ ] Consider optional parity and configurable stop/data-bit widths only after 8N1 is fully verified.
- [ ] Consider RX oversampling/majority sampling for improved noise tolerance.

## Priority 3 — verification quality

- [ ] Split verification into independent TX and RX testbenches in addition to loopback.
- [ ] Check exact TX frame timing and LSB-first order with assertions.
- [ ] Add randomized byte tests and back-to-back frame tests.
- [ ] Test variable idle gaps before `tx_start`.
- [ ] Test false start/noise rejection and framing-error behavior.
- [ ] Test reset during an active frame.
- [ ] Test multiple clock/baud parameter combinations, including divisors above 512 and small divisors.
- [ ] Add functional coverage and SystemVerilog assertions.

## Priority 4 — FPGA implementation

- [ ] Identify the exact FPGA development board and package.
- [ ] Add board-specific pin locations and I/O standards.
- [ ] Add proper input/output timing constraints where required.
- [ ] Program the FPGA and verify loopback or UART communication with a USB-UART adapter.
- [ ] Capture a logic-analyzer trace as physical verification evidence.
