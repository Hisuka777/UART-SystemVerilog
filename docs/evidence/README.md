# UART TX visual verification material

This folder contains screenshots supplied by the project author from Questa Altera Starter FPGA Edition 2025.2. They are actual simulation captures, not generated/illustrative waveforms.

## Hands-on guide

[Open UART TX — Hands-On Verification Guide (PDF)](../guides/UART_TX_Hands_On_Lab_Guide.pdf)

The revised PDF (v2, supplied for local addition) contains five labs: start-bit phase timing, full 8N1 frame, STOP-to-ready timing, busy/next-byte handshake, and corrected TX/RX loopback. The Git-committed PDF is not updated until the binary evidence bundle is added and pushed.

## Captures

1. [START pulse — 434 clock cycles](uart_tx_start_bit_434_cycles.png): cursors 26,250,000 and 34,930,000 ps; delta 8,680,000 ps (434 clocks at 50 MHz). This is an example waveform; separate testbench checked all 434 phases.
2. [Partial DATA state and bit index](uart_tx_data_bit_index_zoom.png): close-up of captured register and bit index, not proof of a complete frame by itself.
3. [STOP-to-ready — 433 clock cycles](uart_tx_stop_to_ready_433_cycles.png): cursors 27,813,000 and 28,679,000 ps; delta 8,660,000 ps; demonstrates current registered handshake timing.

## Results status at the time of preparing this package

- `tb/test_uart_tx.sv`: 434/434 passed, reported by project author from Questa transcript.
- `tb/test_uart_tx_frame.sv`: 5 frame midpoint checks and 9 visible boundary checks passed, reported by project author from Questa transcript.
- `tb/test_uart_tx_handshake.sv`: **PASS, 20 Nov 2026**: 2 complete frames, 1 busy-request rejection, 1 433-clock stop-to-ready check.
- Corrected TX/RX loopback: **PASS, 20 Nov 2026**: 8 patterns passed and 0 failed, no usable waveform captured from this run.
- Physical FPGA testing: **not yet performed**.

Evidence and results refer to 50 MHz, 115200 nominal baud, and `CLKS_PER_BIT=434`.

## New evidence to add from local checkout

- `handshake/busy_request_0xF0_rejected.png`, `handshake/stop_to_ready_433_clocks.png`, `handshake/next_frame_0xA6_accepted.png`: three author-supplied Questa screenshots.
- `handshake/results.log`: concise transcription of the successful handshake test summary.
- `loopback/results.log`: concise transcription of eight successful loopback checks.
- `../guides/UART_TX_Hands_On_Lab_Guide.pdf`: updated visual guide (Lab 04 and Lab 05).

These binary files have been prepared in a separate downloadable ZIP and require a local Git commit. Do not confuse documentation edits with a completed binary upload.
