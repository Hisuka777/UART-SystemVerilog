# Architecture Notes

## Top-level composition

`UART` is the top-level module. It instantiates four RTL blocks:

1. `baud_generator`: generates a one-clock-cycle `baud_tick` based on `CLK_FREQ_HZ / BAUD_RATE`.
2. `uart_tx`: accepts `tx_start` and `tx_data`, then serializes the byte through an FSM.
3. `rx_synchronizer`: uses two flip-flops clocked by `clk` to reduce the chance that asynchronous RX metastability propagates into the receiver logic.
4. `uart_rx`: detects a start bit, validates it near its midpoint, samples eight data bits, checks the stop bit, then asserts `rx_valid`.

## UART format

The current implementation is configured for 8N1: idle high, one low start bit, eight data bits sent LSB first, and one high stop bit.

## Reset and clock

All RTL blocks use the same `clk`. The reset `rst` is active high and synchronous in the current RTL.

## Interface handshake

- TX: the producer presents `tx_data` and asserts `tx_start`; `tx_busy` indicates that the transmitter is occupied. The current testbench waits for `tx_busy` to deassert before sending another byte.
- RX: `rx_data` is updated when a valid stop bit is detected; `rx_valid` pulses to indicate a completed receive byte.

## Architectural note for future revision

The TX currently consumes a free-running `baud_tick`. Since the TX FSM does not restart or phase-align the baud counter when `tx_start` is accepted, the duration of the first start bit can depend on the phase of that tick at the moment a frame starts. This should be corrected and tested with different idle gaps before claiming robust arbitrary-phase UART timing.
