`timescale 1ns/1ps                                      // Simulation time unit = 1 ns, precision = 1 ps

module tb_uart;                                         // Start of the UART testbench module

    // ------------------------------------------------
    // Parameters
    // ------------------------------------------------

    localparam int CLK_FREQ_HZ = 50_000_000;            // FPGA clock frequency = 50 MHz
    localparam int BAUD_RATE   = 115_200;               // UART baud rate = 115200


    // ------------------------------------------------
    // Testbench signals
    // ------------------------------------------------

    logic       clk;                                    // Testbench-generated FPGA clock
    logic       rst;                                    // Reset signal

    logic       tx_start;                               // Pulse requesting a TX transmission
    logic [7:0] tx_data;                                // Parallel byte to transmit

    logic       tx;                                     // Serial TX output from the DUT
    logic       tx_busy;                                // Indicates that TX is currently busy

    logic       rx;                                     // Serial RX input of the DUT

    logic [7:0] rx_data;                                // Byte reconstructed by the DUT RX
    logic       rx_valid;                               // Pulse indicating that rx_data is valid


    // ------------------------------------------------
    // Test statistics
    // ------------------------------------------------

    int tests_passed = 0;                               // Number of successful tests
    int tests_failed = 0;                               // Number of failed tests


    // ------------------------------------------------
    // DUT = Design Under Test
    // ------------------------------------------------

    UART #(                                             // Instantiate the top-level UART module
        .CLK_FREQ_HZ(CLK_FREQ_HZ),                     // Pass the clock frequency parameter to the DUT
        .BAUD_RATE  (BAUD_RATE)                        // Pass the baud-rate parameter to the DUT
    ) dut (                                             // Instance name = dut

        .clk       (clk),                              // Connect testbench clock to DUT clock
        .rst       (rst),                              // Connect reset signal
        .tx_start  (tx_start),                         // Connect TX start command
        .tx_data   (tx_data),                          // Connect transmit data
        .tx        (tx),                               // Connect serial TX output
        .tx_busy   (tx_busy),                          // Connect TX busy status
        .rx        (rx),                               // Connect serial RX input
        .rx_data   (rx_data),                          // Connect received byte
        .rx_valid  (rx_valid)                          // Connect received-byte valid pulse

    );


    // ------------------------------------------------
    // Clock generation
    // ------------------------------------------------

    initial begin                                         // Start the clock-generation process

        clk = 1'b0;                                       // Initialize the clock to logic 0

        forever #10 clk = ~clk;                           // Toggle every 10 ns -> 20 ns period -> 50 MHz

    end                                                   // End clock-generation process


    // ------------------------------------------------
    // UART loopback
    // ------------------------------------------------

    assign rx = tx;                                      // Connect TX directly to RX for loopback testing


    // ------------------------------------------------
    // Reusable task: check one received byte with timeout
    // ------------------------------------------------

    task automatic check_byte(                           // Define a reusable byte-checking task

        input logic [7:0] expected,                      // Expected byte value
        input time timeout_val = 250us                   // Maximum time allowed for RX to respond

    );

        logic timed_out;                                 // Internal flag indicating timeout

        begin                                             // Start task body

            timed_out = 1'b0;                            // Initially assume that no timeout will occur

            fork                                            // Start two parallel processes

                begin                                       // Thread 1: wait for RX event

                    wait (rx_valid == 1'b1);                // Wait until RX reports a received byte

                end                                         // End Thread 1


                begin                                       // Thread 2: watchdog timer

                    #timeout_val;                           // Wait for the configured timeout duration

                    timed_out = 1'b1;                       // Record that the timeout has expired

                end                                         // End Thread 2

            join_any                                        // Continue when either RX arrives or timeout expires

            disable fork;                                   // Stop whichever thread is still running


            // ------------------------------------------------
            // Evaluate result
            // ------------------------------------------------

            if (timed_out) begin                            // Check whether the watchdog timeout occurred

                tests_failed++;                             // Count this test as failed

                $display("=================================");    // Print separator

                $display("         UART TEST TIMEOUT       ");    // Report timeout

                $display("Expected = 0x%02h", expected);          // Print expected byte

                $display("rx_valid did not assert within %0t", timeout_val); // Print timeout duration

                $display("=================================");    // Print separator

                $fatal(1);                                  // Stop simulation because verification failed

            end
            else begin                                      // RX arrived before the timeout

                if (rx_data == expected) begin              // Compare received byte against expected byte

                    tests_passed++;                         // Increment successful-test counter

                    $display("================================="); // Print separator

                    $display("           UART TEST PASS        "); // Report PASS

                    $display("Expected = 0x%02h", expected);       // Print expected byte

                    $display("Received = 0x%02h", rx_data);         // Print actual received byte

                    $display("================================="); // Print separator

                end
                else begin                                  // Received byte does not match expected value

                    tests_failed++;                         // Increment failed-test counter

                    $display("================================="); // Print separator

                    $display("           UART TEST FAIL        "); // Report FAIL

                    $display("Expected = 0x%02h", expected);       // Print expected byte

                    $display("Received = 0x%02h", rx_data);         // Print actual received byte

                    $display("================================="); // Print separator

                    $fatal(1);                              // Stop simulation because verification failed

                end                                             // End PASS/FAIL comparison

                @(posedge clk);                              // Wait one clock so rx_valid can return low

            end                                                 // End timeout/data evaluation

        end                                                     // End task body

    endtask                                                     // End task definition


    // ------------------------------------------------
    // Reusable task: send one byte
    // ------------------------------------------------

    task automatic send_byte(input logic [7:0] data);       // Define a reusable byte-transmission task

        begin                                                 // Start task body

            wait (tx_busy == 1'b0);                           // Wait until transmitter is idle

            tx_data = data;                                   // Put the byte on the TX data interface

            tx_start = 1'b1;                                  // Request the UART to start transmission

            @(posedge clk);                                   // Wait one rising clock edge

            tx_start = 1'b0;                                  // Remove the TX start request

            @(posedge clk);                                   // Give the DUT one additional clock cycle

        end                                                     // End task body

    endtask                                                     // End task definition


    // ------------------------------------------------
    // Main test sequence
    // ------------------------------------------------

    initial begin                                              // Start main test process

        rst      = 1'b1;                                       // Assert reset

        tx_start = 1'b0;                                       // Ensure no transmission request is active

        tx_data  = 8'h00;                                      // Initialize TX data to zero


        // ------------------------------------------------
        // Reset sequence
        // ------------------------------------------------

        repeat (5) @(posedge clk);                             // Hold reset for five clock cycles

        rst = 1'b0;                                             // Release reset


        // ------------------------------------------------
        // TEST 1 : 0x00
        // ------------------------------------------------

        $display("");                                           // Print blank line

        $display(">>> TEST 1: Sending 00");                     // Announce test 1

        send_byte(8'h00);                                       // Transmit byte 0x00

        $display(">>> TEST 1: Checking 00");                    // Announce RX checking

        check_byte(8'h00);                                      // Verify byte 0x00

        $display(">>> TEST 1 COMPLETE");                        // Announce test completion


        // ------------------------------------------------
        // TEST 2 : 0xFF
        // ------------------------------------------------

        $display("");                                           // Print blank line

        $display(">>> TEST 2: Sending FF");                     // Announce test 2

        send_byte(8'hFF);                                       // Transmit byte 0xFF

        $display(">>> TEST 2: Checking FF");                    // Announce RX checking

        check_byte(8'hFF);                                      // Verify byte 0xFF

        $display(">>> TEST 2 COMPLETE");                        // Announce test completion


        // ------------------------------------------------
        // TEST 3 : 0xAA
        // ------------------------------------------------

        $display("");                                           // Print blank line

        $display(">>> TEST 3: Sending AA");                     // Announce test 3

        send_byte(8'hAA);                                       // Transmit byte 0xAA

        $display(">>> TEST 3: Checking AA");                    // Announce RX checking

        check_byte(8'hAA);                                      // Verify byte 0xAA

        $display(">>> TEST 3 COMPLETE");                        // Announce test completion


        // ------------------------------------------------
        // TEST 4 : 0x55
        // ------------------------------------------------

        $display("");                                           // Print blank line

        $display(">>> TEST 4: Sending 55");                     // Announce test 4

        send_byte(8'h55);                                       // Transmit byte 0x55

        $display(">>> TEST 4: Checking 55");                    // Announce RX checking

        check_byte(8'h55);                                      // Verify byte 0x55

        $display(">>> TEST 4 COMPLETE");                        // Announce test completion


        // ------------------------------------------------
        // TEST 5 : 0xA5
        // ------------------------------------------------

        $display("");                                           // Print blank line

        $display(">>> TEST 5: Sending A5");                     // Announce test 5

        send_byte(8'hA5);                                       // Transmit byte 0xA5

        $display(">>> TEST 5: Checking A5");                    // Announce RX checking

        check_byte(8'hA5);                                      // Verify byte 0xA5

        $display(">>> TEST 5 COMPLETE");                        // Announce test completion


        // ------------------------------------------------
        // TEST 6 : 0x3C
        // ------------------------------------------------

        $display("");                                           // Print blank line

        $display(">>> TEST 6: Sending 3C");                     // Announce test 6

        send_byte(8'h3C);                                       // Transmit byte 0x3C

        $display(">>> TEST 6: Checking 3C");                    // Announce RX checking

        check_byte(8'h3C);                                      // Verify byte 0x3C

        $display(">>> TEST 6 COMPLETE");                        // Announce test completion


        // ------------------------------------------------
        // TEST 7 : 0x81
        // ------------------------------------------------

        $display("");                                           // Print blank line

        $display(">>> TEST 7: Sending 81");                     // Announce test 7

        send_byte(8'h81);                                       // Transmit byte 0x81

        $display(">>> TEST 7: Checking 81");                    // Announce RX checking

        check_byte(8'h81);                                      // Verify byte 0x81

        $display(">>> TEST 7 COMPLETE");                        // Announce test completion


        // ------------------------------------------------
        // TEST 8 : 0x18
        // ------------------------------------------------

        $display("");                                           // Print blank line

        $display(">>> TEST 8: Sending 18");                     // Announce test 8

        send_byte(8'h18);                                       // Transmit byte 0x18

        $display(">>> TEST 8: Checking 18");                    // Announce RX checking

        check_byte(8'h18);                                      // Verify byte 0x18

        $display(">>> TEST 8 COMPLETE");                        // Announce test completion


        // ------------------------------------------------
        // Final summary
        // ------------------------------------------------

        $display("");                                           // Print blank line

        $display(">>> ALL TESTS COMPLETE");                     // Announce that all tests completed

        $display("");                                           // Print blank line

        $display("=================================");             // Print summary separator

        $display("          TEST SUMMARY           ");             // Print summary title

        $display("Tests passed = %0d", tests_passed);              // Print number of successful tests

        $display("Tests failed = %0d", tests_failed);              // Print number of failed tests

        $display("=================================");             // Print summary separator


        $finish;                                                 // End simulation

    end                                                         // End main test process


endmodule                                                       // End of testbench module