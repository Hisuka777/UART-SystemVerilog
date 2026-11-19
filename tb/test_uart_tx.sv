`timescale 1ns/1ps

// Dedicated UART TX start-bit phase test.
//
// This test intentionally uses the existing, unmodified uart_tx.sv and the
// real baud_generator. It checks whether a tx_start request made at different
// phases of the free-running baud generator still produces a full start bit.
//
// Payload 8'hFF is used so D0 is HIGH. The rising edge after the LOW start bit
// therefore marks the end of the start bit and makes its duration measurable.

module test_uart_tx;

    localparam int CLK_FREQ_HZ  = 50_000_000;
    localparam int BAUD_RATE    = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE; // 434
    localparam time CLK_PERIOD  = 20ns;                    // 50 MHz

    logic clk;
    logic rst;
    logic baud_tick;
    logic tx_start;
    logic [7:0] tx_data;
    logic tx;
    logic tx_busy;

    int tests_passed = 0;
    int tests_failed = 0;

    // Clock: 50 MHz.
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Use the actual project baud generator, not a hand-written tick source.
    baud_generator #(
        .CLK_FREQ_HZ  (CLK_FREQ_HZ),
        .BAUD_RATE    (BAUD_RATE),
        .CLKS_PER_BIT (CLKS_PER_BIT)
    ) u_baud_generator (
        .clk       (clk),
        .rst       (rst),
        .baud_tick (baud_tick)
    );

    // Test the TX block in isolation so the measurement is independent of RX.
    uart_tx u_uart_tx (
        .clk       (clk),
        .rst       (rst),
        .baud_tick (baud_tick),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx        (tx),
        .tx_busy   (tx_busy)
    );

    task automatic reset_dut;
        begin
            rst      = 1'b1;
            tx_start = 1'b0;
            tx_data  = 8'hFF;

            // Synchronous reset; hold across several rising edges.
            repeat (4) @(negedge clk);
            rst = 1'b0;
        end
    endtask

    task automatic check_start_bit_width(input int idle_phase_cycles);
        time start_edge_time;
        time end_edge_time;
        int measured_cycles;
        begin
            reset_dut();

            // Shift tx_start relative to the free-running baud-generator phase.
            repeat (idle_phase_cycles) @(negedge clk);

            tx_data  = 8'hFF; // D0=1, so tx rises immediately after the start bit.
            tx_start = 1'b1;
            @(negedge clk);
            tx_start = 1'b0;

            // Measure the LOW pulse from the start bit to the first data bit.
            // The watchdog prevents a hung test from waiting indefinitely.
            fork : measure_or_timeout
                begin : measure_pulse
                    @(negedge tx);
                    start_edge_time = $time;

                    @(posedge tx);
                    end_edge_time = $time;

                    measured_cycles = (end_edge_time - start_edge_time) / CLK_PERIOD;
                end

                begin : watchdog
                    #( (CLKS_PER_BIT + 20) * CLK_PERIOD );
                    $fatal(1,
                        "TIMEOUT: no complete start-bit pulse observed at phase offset %0d",
                        idle_phase_cycles);
                end
            join_any
            disable measure_or_timeout;

            if (measured_cycles == CLKS_PER_BIT) begin
                tests_passed++;
                $display(
                    "PASS: phase_offset=%0d cycles, measured_start_bit=%0d cycles",
                    idle_phase_cycles, measured_cycles);
            end else begin
                tests_failed++;
                $display(
                    "FAIL: phase_offset=%0d cycles, measured_start_bit=%0d cycles, expected=%0d",
                    idle_phase_cycles, measured_cycles, CLKS_PER_BIT);
            end
        end
    endtask

    initial begin
        rst      = 1'b1;
        tx_start = 1'b0;
        tx_data  = 8'hFF;

        $display("============================================================");
        $display("UART TX start-bit phase test");
        $display("Clock=%0d Hz, baud=%0d, CLKS_PER_BIT=%0d", 
                 CLK_FREQ_HZ, BAUD_RATE, CLKS_PER_BIT);
        $display("Expected start-bit width: %0d clock cycles", CLKS_PER_BIT);
        $display("============================================================");

        // Each trial resets both DUT blocks, then shifts tx_start relative to
        // the baud generator. Offset 0 is the aligned/reference case; the
        // other offsets exercise different points within the baud period.
        check_start_bit_width(0);
        check_start_bit_width(1);
        check_start_bit_width(108);
        check_start_bit_width(217);
        check_start_bit_width(324);
        check_start_bit_width(432);

        $display("------------------------------------------------------------");
        $display("TX phase-test summary: %0d passed, %0d failed",
                 tests_passed, tests_failed);
        $display("------------------------------------------------------------");

        if (tests_failed != 0) begin
            $fatal(1,
                "TX phase test FAILED. A phase-independent TX must produce a %0d-cycle start bit for every trial.",
                CLKS_PER_BIT);
        end else begin
            $display("ALL TX PHASE TESTS PASSED.");
            $finish;
        end
    end

endmodule
