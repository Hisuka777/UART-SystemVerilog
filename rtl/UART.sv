module UART #(
    parameter int CLK_FREQ_HZ = 50_000_000,
    parameter int BAUD_RATE   = 115_200
)(
    input  logic       clk,
    input  logic       rst,

    // TX interface
    input  logic       tx_start,
    input  logic [7:0] tx_data,

    output logic       tx,
    output logic       tx_busy,

    // RX interface
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_valid
);

    // ----------------------------------------------------
    // Derived parameter
    // ----------------------------------------------------
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    // ----------------------------------------------------
    // Internal signals
    // ----------------------------------------------------
    logic baud_tick;
    logic rx_sync;


    // ----------------------------------------------------
    // 1. Baud Generator
    // ----------------------------------------------------
    baud_generator #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_baud_gen (
        .clk       (clk),
        .rst       (rst),
        .baud_tick (baud_tick)
    );


    // ----------------------------------------------------
    // 2. UART Transmitter
    // ----------------------------------------------------
    uart_tx u_uart_tx (
        .clk       (clk),
        .rst       (rst),
        .baud_tick (baud_tick),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx        (tx),
        .tx_busy   (tx_busy)
    );


    // ----------------------------------------------------
    // 3. RX Synchronizer
    // ----------------------------------------------------
    rx_synchronizer u_rx_sync (
        .clk     (clk),
        .rst     (rst),
        .rx      (rx),
        .rx_sync (rx_sync)
    );


    // ----------------------------------------------------
    // 4. UART Receiver
    // ----------------------------------------------------
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_uart_rx (
        .clk      (clk),
        .rst      (rst),
        .rx_sync  (rx_sync),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

endmodule