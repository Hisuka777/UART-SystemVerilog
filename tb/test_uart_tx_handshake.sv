`timescale 1ns/1ps

// Independent TX handshake regression (no RX in the checker).
// Requirements tested:
// 1) A one-clock tx_start pulse while busy is ignored and does not overwrite data_reg.
// 2) A normal request made when idle produces the next complete 8N1 frame.
// 3) Stop-to-ready timing for 8'h53 (D7=0) is 433 system clocks in this RTL.
// Stimulus is applied on negative clk edges to avoid DUT clock-edge races.
module test_uart_tx_handshake;
    localparam int CLK_FREQ_HZ = 50_000_000;
    localparam int BAUD_RATE   = 115_200;
    localparam int CPB         = CLK_FREQ_HZ / BAUD_RATE; // 434
    localparam int HALF_CPB    = CPB / 2;
    localparam time CLK_PERIOD = 20ns;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic baud_tick;
    logic tx_start = 1'b0;
    logic [7:0] tx_data = 8'h00;
    logic tx, tx_busy;
    int frames_passed = 0;
    int busy_rejects_passed = 0;
    int stop_checks_passed = 0;

    always #(CLK_PERIOD/2) clk = ~clk;

    baud_generator #(.CLK_FREQ_HZ(CLK_FREQ_HZ),
                     .BAUD_RATE(BAUD_RATE),
                     .CLKS_PER_BIT(CPB)) u_baud_generator (
        .clk(clk), .rst(rst), .baud_tick(baud_tick)
    );
    uart_tx u_uart_tx (
        .clk(clk), .rst(rst), .baud_tick(baud_tick),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy)
    );

    task automatic request_byte(input logic [7:0] value);
        @(negedge clk);
        tx_data  = value;
        tx_start = 1'b1;
        @(negedge clk);
        tx_start = 1'b0;
    endtask

    // Independent, bit-centered checker for a 10-slot (8N1) frame.
    task automatic check_frame(input logic [7:0] value);
        logic expected;
        @(negedge tx); // START falling edge
        if (tx_busy !== 1'b1)
            $fatal(1, "tx_busy not HIGH at START for %02h", value);
        if (u_uart_tx.data_reg !== value)
            $fatal(1, "Incorrect captured data: expected %02h, got %02h",
                   value, u_uart_tx.data_reg);

        for (int slot = 0; slot < 10; slot++) begin
            #(HALF_CPB * CLK_PERIOD);
            if (slot == 0)       expected = 1'b0;        // START
            else if (slot == 9)  expected = 1'b1;        // STOP
            else                 expected = value[slot-1]; // D0..D7
            if (tx !== expected)
                $fatal(1, "Frame %02h, slot %0d: expected %b, got %b",
                       value, slot, expected, tx);
            #((CPB-HALF_CPB) * CLK_PERIOD);
        end
        #1ps; // After the NBA updates at the stop-completion clock edge.
        if (tx !== 1'b1 || tx_busy !== 1'b0)
            $fatal(1, "Frame %02h did not return to ready/idle", value);
        frames_passed++;
        $display("PASS: 8N1 frame %02h completed and TX became ready", value);
    endtask

    task automatic pulse_request_while_busy;
        @(negedge tx); // start of the first frame
        #(3 * CPB * CLK_PERIOD); // assert during payload portion
        @(negedge clk);
        if (tx_busy !== 1'b1)
            $fatal(1, "Not busy before the rejected request");
        tx_data  = 8'hF0;
        tx_start = 1'b1;
        @(negedge clk);
        tx_start = 1'b0;
        #1ps;
        if (u_uart_tx.data_reg !== 8'h53 || tx_busy !== 1'b1)
            $fatal(1, "Busy request incorrectly overwritten 0x53 or cleared busy");
        busy_rejects_passed++;
        $display("PASS: busy request 0xF0 ignored; data_reg remains 0x53");
    endtask

    task automatic check_stop_to_ready_53;
        time stop_rise;
        time ready_fall;
        time measured;
        @(negedge tx);
        // D7 is LOW for 0x53. Look for STOP rising edge in the
        // latter half of the D7 period, not earlier data transitions.
        #((8 * CPB + HALF_CPB) * CLK_PERIOD);
        @(posedge tx);
        stop_rise = $time;
        @(negedge tx_busy);
        ready_fall = $time;
        measured = ready_fall - stop_rise;
        if (measured != (CPB - 1) * CLK_PERIOD)
            $fatal(1, "Stop-to-ready interval %0t, expected %0t",
                   measured, (CPB-1) * CLK_PERIOD);
        stop_checks_passed++;
        $display("PASS: stop-to-ready interval = %0d clocks", CPB-1);
    endtask

    initial begin
        #5ms;
        $fatal(1, "TIMEOUT: handshake test stalled");
    end

    initial begin
        // Reset across several rising clock edges.
        repeat (5) @(negedge clk);
        rst = 1'b0;

        request_byte(8'h53);
        fork
            check_frame(8'h53);
            pulse_request_while_busy();
            check_stop_to_ready_53();
        join

        // Send a new valid request as soon as a synchronous source can
        // observe busy LOW and drive tx_start at a subsequent negedge.
        request_byte(8'hA6);
        check_frame(8'hA6);

        $display("TX HANDSHAKE SUMMARY: %0d frames, %0d busy-request rejection, %0d stop-to-ready timing check passed",
                 frames_passed, busy_rejects_passed, stop_checks_passed);
        $finish;
    end
endmodule
