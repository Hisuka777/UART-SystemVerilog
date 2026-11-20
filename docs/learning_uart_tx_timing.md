# Learning note 01 — UART TX timing, FSM alignment, and verification

> **Purpose:** Explain *why* the transmitter was changed, how the corrected FSM works, and how the timing tests establish its behavior. This is a learning record, not a claim of production-ready UART IP.

## What the interface means

- `tx_data[7:0]` is an 8-bit **parallel** bus. Presenting `8'hFF` sets eight input wires simultaneously; it does not mean that the UART has transmitted eight serial bits.
- `tx_start` is the request accepted in `STATE_IDLE`. The byte is copied to `data_reg`.
- `tx` is the **single-wire serial** output. Idle is HIGH, start is LOW, D0 is sent first, and stop is HIGH.
- `baud_tick` is a **one-system-clock-wide enable pulse**, recurring every `CLKS_PER_BIT` system-clock cycles. It is not another UART data bit or a separate transmitted clock.
- `tx_busy` indicates that the transmitter has accepted a request and is completing it. Requests asserted while busy are ignored by this RTL; no queue is implemented.

## Numerical timing example

For `CLK_FREQ_HZ=50_000_000` and `BAUD_RATE=115_200`:

```text
System clock period     = 1 / 50,000,000 = 20 ns = 20,000 ps
Integer clocks per bit  = 50,000,000 / 115,200 = 434 (truncated)
Actual UART bit period  = 434 * 20 ns = 8.680 us = 8,680,000 ps
Actual generated baud   = 50,000,000 / 434 = 115,207.37 baud
Baud-rate error         = +0.0064% approximately
```

`baud_tick` stays HIGH for one **20 ns** clock, but consecutive baud ticks occur **8.68 us** apart.

### A serial frame is 10 bit periods for 8N1

Example payload: `8'h53 = 8'b0101_0011` (normal binary display D7..D0).

```text
Time slot:   START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | STOP
TX level:       0  |  1 |  1 |  0 |  0 |  1 |  0 |  1 |  0 |   1
Duration:   [434] [434][434][434][434][434][434][434][434] [434] clocks
```

At a boundary between two equal levels (for example D0=1 and D1=1), the serial line **does not change**, although a new bit period begins. Count time slots or sample their midpoints, not merely waveform transitions.

## The defect in the original four-state transmitter

The baseline `rtl/uart_tx.sv` used:

```systemverilog
typedef enum logic [1:0] {
    STATE_IDLE  = 2'b00,
    STATE_START = 2'b01,
    STATE_DATA  = 2'b10,
    STATE_STOP  = 2'b11
} state_t;

// In STATE_IDLE, on tx_start:
data_reg <= tx_data;
tx_busy  <= 1'b1;
state    <= STATE_START;

// In STATE_START:
tx <= 1'b0;
if (baud_tick)
    state <= STATE_DATA;
```

Because the generator is free-running, `tx_start` can arrive at any point in the baud period. `STATE_START` starts driving LOW without first aligning its beginning to the generator. It then ends on the next tick, making its LOW duration dependent on the phase at which the request was accepted.

**Measured baseline (Questa, 12 Nov 2026):**

| Phase offset (system clocks) | LOW start bit (system clocks) | Expected |
|---:|---:|---:|
| 0 | 434 | 434 |
| 1 | 433 | 434 |
| 108 | 326 | 434 |
| 217 | 217 | 434 |
| 324 | 110 | 434 |
| 432 | 2 | 434 |

The original test passed only 1 out of 6 phase offsets. A loopback test can miss the error if the transmitter and receiver happen to tolerate the same timing conditions.

## The minimal correction — a fifth state

We retained the real `baud_generator`, the data register, the bit index, and the START / DATA / STOP behavior. Only the entry to the frame changed.

**Before:**
```text
IDLE --tx_start--> START --baud_tick--> DATA --> STOP --> IDLE
```

**After:**
```text
IDLE --tx_start--> WAIT_BAUD --baud_tick--> START --next baud_tick--> DATA --> STOP --> IDLE
                    tx stays HIGH                  tx LOW
```

### Code difference 1 — state encoding

```systemverilog
// Before: four possible states need at least 2 encoding bits.
typedef enum logic [1:0] {
    STATE_IDLE = 2'b00, STATE_START = 2'b01,
    STATE_DATA = 2'b10, STATE_STOP = 2'b11
} state_t;

// After: five possible states need at least 3 binary encoding bits.
typedef enum logic [2:0] {
    STATE_IDLE      = 3'd0,
    STATE_WAIT_BAUD = 3'd1,
    STATE_START     = 3'd2,
    STATE_DATA      = 3'd3,
    STATE_STOP      = 3'd4
} state_t;
```

The declared state width changed from 2 to 3 bits. The synthesizer may re-encode the FSM, so these declarations do not necessarily predict its final number of state flip-flops.

### Code difference 2 — IDLE's destination

```systemverilog
// Before:
if (tx_start) begin
    data_reg <= tx_data;
    tx_busy  <= 1'b1;
    state    <= STATE_START;
end

// After:
if (tx_start) begin
    data_reg <= tx_data;
    tx_busy  <= 1'b1;
    state    <= STATE_WAIT_BAUD;
end
```

The request still latches the byte and raises busy immediately. The serial start bit now waits for alignment.

### Code difference 3 — newly added WAIT_BAUD

```systemverilog
STATE_WAIT_BAUD: begin
    tx <= 1'b1;  // remain idle HIGH
    if (baud_tick)
        state <= STATE_START;
end
```

Why **not** also set `tx <= 0` here? The original `STATE_START` already owns that registered output. Splitting ownership carelessly can introduce a one-cycle mismatch at the boundary.

### Nonblocking-assignment timing (critical)

On a rising `clk` where `STATE_WAIT_BAUD` observes `baud_tick==1`, `state <= STATE_START` is scheduled for the end of that time step. `tx` stays HIGH. On the **next** rising edge, `STATE_START` executes `tx <= 0`. Since consecutive baud-enable pulses occur 434 cycles apart, the next data-bit transition is also 434 cycles later. This is why the corrected start bit lasts one full period.

A tradeoff: after `tx_start` is accepted, the transmitter remains busy while waiting for the next baud boundary. The start edge can be delayed by almost a bit period. A transmitter-local timing divider could remove that phase-dependent launch latency, but it was **not** implemented in this milestone.

### Conceptual timing chart (not a simulator capture)

```text
                 request              aligned boundary       next boundary
clk:         ^  ^  ^  ^  ^  ...       ^  ^  ^  ...          ^
tx_start:       ____|‾|_______________________________
baud_tick:   ________________________|‾|_________________|‾|__
state:       IDLE -> WAIT_BAUD ------> START -------------> DATA
tx:          ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___________________/‾‾ (if D0=1)
                                     <--- 434 clocks --->
```

Diagram not drawn to scale; pulse/state edges are subject to the registered-output behavior just described. Use the actual Questa waveform and cursors for timing evidence.

## Verification strategy: prove distinct properties independently

### A — Start-bit phase test (`tb/test_uart_tx.sv`)

- Uses the real `baud_generator` and `uart_tx`.
- Tests each initial phase offset 0..433 with `8'hFF`.
- Since D0=1, the first rising edge of `tx` after its LOW start pulse marks the end of the start bit.
- Checks that the LOW duration is **434 cycles**.
- Allows the initial WAIT_BAUD latency in its watchdog.

**Observed 19 Nov 2026:** `TX phase-test summary: 434 passed, 0 failed`.

A provided Wave-window screenshot shows the LOW pulse from 26,250,000 ps to 34,930,000 ps, a delta of **8,680,000 ps**, corresponding to 434 clocks. This is one illustrative measurement in addition to the automated phase sweep.

### B — Complete-frame test (`tb/test_uart_tx_frame.sv`)

- Sends `55`, `AA`, `53`, `00`, `FF`.
- Samples the expected start, D0..D7, and stop **near each bit midpoint**.
- Changes the external `tx_data` after request acceptance to ensure the registered byte is used.
- Checks `tx_busy` at the frame start and after the frame.
- With `8'h55`, checks **nine consecutive visible transitions**, each spaced 434 cycles apart. Equal neighboring bits would not provide a measurable edge.

**Observed 19 Nov 2026:**

```text
PASS: complete 8N1 midpoint sequence for 55
PASS: complete 8N1 midpoint sequence for aa
PASS: complete 8N1 midpoint sequence for 53
PASS: complete 8N1 midpoint sequence for 00
PASS: complete 8N1 midpoint sequence for ff
PASS: 0x55 all nine visible boundaries are 434 clocks apart
TX FRAME SUMMARY: 5 frames passed, 9 edge intervals passed
```

Both result sets are from the project author's provided Questa Altera Starter FPGA Edition 2025.2 transcripts. They have not been independently rerun in another simulator.

### Reproduce in Questa

Run from the repository root, with a simulation library for this test:

```tcl
vlib work_frame
vlog -work work_frame -sv rtl/baud_generator.sv
vlog -work work_frame -sv rtl/uart_tx.sv
vlog -work work_frame -sv tb/test_uart_tx_frame.sv
vsim -t 1ps -voptargs=+acc work_frame.test_uart_tx_frame
view wave
add wave -r sim:/test_uart_tx_frame/*
run -all
```

If the design is already loaded and you need to change directories, use `quit -sim` first. For an uncluttered waveform, zoom into one of the `0x55` frames.

## What is NOT yet verified

These passing tests do **not** establish:
- Complete stop/ready handshake timing under back-to-back requests;
- Defined behavior for `tx_start` pulses while `tx_busy` is HIGH beyond the basic fact that there is no queuing;
- Reset during an active frame;
- Parameterization at other baud rates or clocks;
- RX framing-error handling or receiver counter-width robustness;
- Post-fix UART TX/RX loopback, Quartus timing closure, pin assignments, or actual FPGA operation.

## What to inspect in the waveform next

1. Display `clk`, `tx_start`, `tx_busy`, `baud_tick`, `tx`, `u_uart_tx/state`, and `u_uart_tx/bit_idx`.
2. Select the `0x55` frame: bit pattern D0..D7 is `1,0,1,0,1,0,1,0`.
3. Measure adjacent visible `tx` edges: `8,680,000 ps` each at the default configuration.
4. Locate `WAIT_BAUD`: `tx_busy=1` and `tx=1` until start alignment.
5. Save an annotated screenshot in `docs/evidence/` and a brief text transcript; avoid committing huge .wlf/.vcd files.

## Next learning milestone

Build and verify a **back-to-back transmission and stop-bit ready/handshake test** and rerun the pre-existing UART loopback regression. Only then move toward merging the TX fix into `main`.

---

This file is a didactic engineering notebook. Keep the README brief and link here; keep factual before/after results and limitations under [tx_start_bit_debug.md](tx_start_bit_debug.md).

## Learning note 02 — Busy rejection and consecutive frames (pending Questa)

### What the current RTL does

The `if (tx_start)` conditional is **inside `STATE_IDLE` only**. During `WAIT_BAUD`, `START`, `DATA`, or `STOP`, a one-clock `tx_start` pulse is not accepted and `data_reg` does not change. There is **no pending-request queue**.

```text
Request #1:   0x53   -- accepted in IDLE
busy:         ______/-------------------------\______ /------
Request #2:               0xF0 -- ignored while busy
data_reg:     0x53   ------------------------------> 0xA6
Request #3:                                        0xA6 -- accepted in IDLE
```

Diagram is conceptual, not measured. The first request is accepted when the FSM is IDLE and `tx_start` is sampled HIGH at `posedge clk`. A bus value change or the falling edge of `tx_start` is not itself a capture event.

### Why the STOP bit needs a handshake check

The serial output goes HIGH in `STATE_STOP` and stays HIGH in IDLE; the end of the stop slot is not visible from the serial pin alone. We can compare the rising `tx` edge marking STOP (for a byte with D7=0) to the falling `tx_busy` edge. For this RTL, the predicted duration is **433 system clocks** (8.66 microseconds at 50 MHz), one system clock less than the nominal 434-clock bit period because output and state are registered.

This may be acceptable as an interface-ready timing detail, but it should be explicitly tested and documented. New requests must be applied while the FSM is in IDLE; `tx_busy` LOW is useful as a readiness indicator for synchronously driven requests.

### Independent testbench

`tb/test_uart_tx_handshake.sv` exercises:

1. Transmit `0x53` and independently check all ten 8N1 bit-slot midpoints.
2. Pulse `tx_start` for `0xF0` while `tx_busy=1`; verify `data_reg` remains `0x53`.
3. Measure STOP rising edge to `tx_busy` falling edge, expected **433 clocks** for this version.
4. Wait for completion and send a second valid byte `0xA6`; independently verify the complete second frame.

**Status: new test not yet executed in Questa.** A passing result is required before updating the table or marking this milestone verified.

Run in Questa from the repository root:

```tcl
quit -sim
cd {C:/Users/hp/Downloads/UART/UART-SystemVerilog}
vlib work_handshake
vlog -work work_handshake -sv rtl/baud_generator.sv
vlog -work work_handshake -sv rtl/uart_tx.sv
vlog -work work_handshake -sv tb/test_uart_tx_handshake.sv
vsim -t 1ps -voptargs=+acc work_handshake.test_uart_tx_handshake
view wave
add wave -r sim:/test_uart_tx_handshake/*
run -all
```

Expected, not yet observed: `TX HANDSHAKE SUMMARY: 2 frames, 1 busy-request rejection, 1 stop-to-ready timing check passed`.

After this test succeeds, rerun the pre-existing TX/RX loopback test using the corrected TX and review its testbench clock-edge stimulus for any races.
