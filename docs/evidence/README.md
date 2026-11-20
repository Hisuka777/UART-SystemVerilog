# UART TX visual verification material

This folder contains screenshots supplied by the project author from Questa Altera Starter FPGA Edition 2025.2. They are actual simulation captures, not generated/illustrative waveforms.

## Hands-on guide

[Open UART TX — Hands-On Verification Guide (PDF)](../guides/UART_TX_Hands_On_Lab_Guide.pdf)

The PDF contains four labs, each linked to a specific testbench or verification objective: start-bit phase timing, complete 8N1 frame, STOP-to-ready timing and busy/next-byte handshake. The busy/next-byte handshake lab is marked pending simulation.

## Captures

1. [START pulse — 434 clock cycles](uart_tx_start_bit_434_cycles.png): cursors 26,250,000 and 34,930,000 ps; delta 8,680,000 ps (434 clocks at 50 MHz). This is an example waveform; separate testbench checked all 434 phases.
2. [Partial DATA state and bit index](uart_tx_data_bit_index_zoom.png): close-up of captured register and bit index, not proof of a complete frame by itself.
3. [STOP-to-ready — 433 clock cycles](uart_tx_stop_to_ready_433_cycles.png): cursors 27,813,000 and 28,679,000 ps; delta 8,660,000 ps; demonstrates current registered handshake timing.

## Results status at the time of preparing this package

- `tb/test_uart_tx.sv`: 434/434 passed, reported by project author from Questa transcript.
- `tb/test_uart_tx_frame.sv`: 5 frame midpoint checks and 9 visible boundary checks passed, reported by project author from Questa transcript.
- `tb/test_uart_tx_handshake.sv`: **not yet run**. No passing result claimed.
- Corrected TX/RX loopback and physical FPGA test: not yet demonstrated after TX changes.

Evidence and results refer to 50 MHz, 115200 nominal baud, and `CLKS_PER_BIT=434`.
