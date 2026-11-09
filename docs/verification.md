# Verification and Implementation Record

This document records evidence present in the supplied Quartus project ZIP. It does not claim tests beyond those represented by the saved transcripts and reports.

## Questa simulation

Tool recorded in transcript: Questa Altera Starter FPGA Edition 2025.2.

The latest transcript dated 9 November 2026 shows:
- RTL compilation: 0 errors, 0 warnings.
- Testbench compilation: 0 errors, 0 warnings.
- Test vectors: `00`, `FF`, `AA`, `55`, `A5`, `3C`, `81`, `18`.
- Result: **8 passed, 0 failed**.
- Simulation end time reported by the testbench: approximately 690.29 µs.
- The simulator transcript records three warnings at the end, including a warning about a WLF file already being in use; these did not prevent the testbench from completing.

The testbench is a TX-to-RX loopback: `assign rx = tx`. This verifies the integrated loopback path for the eight data patterns, but is not a substitute for independent TX waveform verification, independent RX stimulus, protocol stress testing, or physical hardware testing.

## Quartus compilation / fitting

Quartus Prime Standard/Lite 25.1 reports dated 9 November 2026 show:
- Analysis & Synthesis: Successful.
- Fitter: Successful.
- Target: Cyclone V `5CGXFC7C7F23C8`.
- Logic utilization: 45 ALMs.
- Total registers: 62.
- Total pins: 23.
- Timing Analyzer summary: positive setup and hold slack for the 20 ns `clk` constraint.

### Important fitter warning

The Fitter report contains Critical Warning 169085: **no exact pin location assignments for 23 of 23 pins**. The project has no board-specific pin mapping. It must not be described as physically validated on an FPGA board until the correct board part/pinout is selected, I/O standards and pin locations are assigned, and the design is programmed and tested.

The SDC currently contains only:

```tcl
create_clock -name clk -period 20.000 [get_ports clk]
```

There are no explicit input/output delay constraints. Timing results therefore relate to the constrained internal clock path and do not constitute a complete board-level I/O timing sign-off.

## What is not included

The ZIP contained generated Quartus databases, compiled simulation libraries, WLF/VCD waveforms, backup source copies and a `.sof` output. These have been excluded from the GitHub baseline to keep the repository source-focused and reproducible. The summary above is transcribed from the supplied reports/transcript.
