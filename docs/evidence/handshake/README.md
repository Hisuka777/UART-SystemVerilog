# UART TX handshake verification - 2026-11-20

All images are actual author-provided Questa captures.

- `busy_request_0xF0_rejected.png`: during 0x53, a one-cycle 0xF0 request is ignored while `tx_busy` is HIGH; `data_reg` stays 0x53. Screenshot is a partial zoom.
- `stop_to_ready_433_clocks.png`: cursors show 8,660,000 ps = 433 cycles from STOP rising edge to busy falling edge.
- `next_frame_0xA6_accepted.png`: after IDLE, 0xA6 is accepted. Complete frame checked by testbench.
- `results.log`: concise results transcribed from the author-supplied Questa Transcript.

See `../../guides/UART_TX_Hands_On_Lab_Guide.pdf` (Lab 04) for figures and explanations. These results do not establish reset-during-frame or physical FPGA verification.
