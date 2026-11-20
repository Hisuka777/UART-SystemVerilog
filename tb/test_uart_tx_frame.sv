`timescale 1ns/1ps

// Independent UART TX frame-level regression.
// Uses the real baud_generator and uart_tx, not the UART receiver.
// Clock: 50 MHz; nominal baud: 115200; divisor: 434.
// Run from the repository root using the commands in docs/tx_start_bit_debug.md.
module test_uart_tx_frame;
    localparam int CLK_FREQ_HZ  = 50_000_000;
    localparam int BAUD_RATE    = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam int HALF_BIT     = CLKS_PER_BIT / 2;
    localparam time CLK_PERIOD  = 20ns;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic baud_tick;
    logic tx_start = 1'b0;
    logic [7:0] tx_data = '0;
    logic tx;
    logic tx_busy;
    int frames_passed = 0;
    int edges_passed = 0;

    always #(CLK_PERIOD / 2) clk = ~clk;

    baud_generator #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_baud_generator (
        .clk(clk), .rst(rst), .baud_tick(baud_tick)
    );

    uart_tx u_uart_tx (
        .clk(clk), .rst(rst), .baud_tick(baud_tick),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy)
    );

    // Drive request on falling clock edges, away from DUT's positive edges.
    task automatic launch(input logic [7:0] payload);
        begin
            @(negedge clk);
            rst = 1'b1;
            tx_start = 1'b0;
            repeat (4) @(negedge clk);
            rst = 1'b0;
            repeat (3) @(negedge clk);
            tx_data = payload;
            tx_start = 1'b1;
            @(negedge clk);
            tx_start = 1'b0;
            // Prove that TX holds its registered byte instead of
            // reading the parallel input continuously.
            tx_data = ~payload;
        end
    endtask

    // Check the midpoint of all 10 bit cells: start, 8 data, stop.
    // This verifies payload/order/stop values but not every boundary width.
    task automatic check_frame(input logic [7:0] payload);
        logic expected;
        begin
            launch(payload);
            @(negedge tx);
            if (tx_busy !== 1'b1)
                $fatal(1, "tx_busy not asserted when frame begins: %02h", payload);

            for (int slot = 0; slot < 10; slot++) begin
                #(HALF_BIT * CLK_PERIOD);
                if (slot == 0) expected = 1'b0;
                else if (slot == 9) expected = 1'b1;
                else expected = payload[slot-1];

                if (tx !== expected)
                    $fatal(1,
                        "Frame %02h slot %0d: expected tx=%b observed tx=%b at %0t",
                        payload, slot, expected, tx, $time);

                #((CLKS_PER_BIT - HALF_BIT) * CLK_PERIOD);
            end

            if (tx !== 1'b1 || tx_busy !== 1'b0)
                $fatal(1, "Frame %02h failed final idle/busy check", payload);

            frames_passed++;
            $display("PASS: complete 8N1 midpoint sequence for %02h", payload);
        end
    endtask

    // 0x55 transitions on EVERY boundary: START->D0, D0->D1 ... D7->STOP.
    // The nine consecutive edge spacings must each be exactly 434 clocks.
    task automatic check_all_visible_boundaries_55;
        time last_edge_time;
        time this_edge_time;
        time measured;
        begin
            launch(8'h55);
            @(negedge tx);
            last_edge_time = $time;
            for (int boundary = 0; boundary < 9; boundary++) begin
                if ((boundary % 2) == 0) @(posedge tx);
                else                      @(negedge tx);
                this_edge_time = $time;
                measured = this_edge_time - last_edge_time;
                if (measured != CLKS_PER_BIT * CLK_PERIOD)
                    $fatal(1,
                        "0x55 boundary %0d width=%0t ps, expected=%0t ps",
                        boundary, measured, CLKS_PER_BIT * CLK_PERIOD);
                last_edge_time = this_edge_time;
                edges_passed++;
            end
            $display("PASS: 0x55 all nine visible boundaries are %0d clocks apart",
                     CLKS_PER_BIT);
        end
    endtask

    initial begin
        // A broken DUT must not hang the simulator indefinitely.
        #10ms;
        $fatal(1, "TIMEOUT: UART TX full-frame regression did not complete");
    end

    initial begin
        check_frame(8'h55);
        check_frame(8'hAA);
        check_frame(8'h53);
        check_frame(8'h00);
        check_frame(8'hFF);
        check_all_visible_boundaries_55();
        $display("TX FRAME SUMMARY: %0d frames passed, %0d edge intervals passed",
                 frames_passed, edges_passed);
        $finish;
    end
endmodule
