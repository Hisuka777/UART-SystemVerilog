module baud_generator #(
    parameter int CLK_FREQ_HZ  = 50_000_000,
    parameter int BAUD_RATE    = 115_200,
    parameter int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE
)(
    input  logic clk,
    input  logic rst,
    output logic baud_tick
);

    // Auto-calculated counter size to prevent overflow bugs
    logic [$clog2(CLKS_PER_BIT)-1:0] baud_counter;

    always_ff @(posedge clk) begin
        if (rst) begin
            baud_counter <= '0;
            baud_tick    <= 1'b0;
        end else if (baud_counter >= CLKS_PER_BIT - 1) begin
            baud_counter <= '0;
            baud_tick    <= 1'b1;
        end else begin
            baud_counter <= baud_counter + 1'b1;
            baud_tick    <= 1'b0;
        end
    end

endmodule