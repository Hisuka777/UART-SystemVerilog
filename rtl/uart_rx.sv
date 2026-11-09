module uart_rx #(
    parameter int CLKS_PER_BIT = 434
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       rx_sync,

    output logic [7:0] rx_data,
    output logic       rx_valid
);

    localparam int HALF_BIT = CLKS_PER_BIT / 2;

    typedef enum logic [1:0] {
        STATE_IDLE  = 2'b00,
        STATE_START = 2'b01,
        STATE_DATA  = 2'b10,
        STATE_STOP  = 2'b11
    } state_t;

    state_t state;

    logic [7:0] data_reg;
    logic [2:0] bit_idx;

    logic [8:0] rx_counter;


    always_ff @(posedge clk) begin

        if (rst) begin

            state      <= STATE_IDLE;
            data_reg   <= 8'd0;
            bit_idx    <= 3'd0;
            rx_counter <= 9'd0;
            rx_valid   <= 1'b0;
            rx_data    <= 8'd0;

        end else begin

            case (state)

                // --------------------------------
                // IDLE
                // --------------------------------
                STATE_IDLE: begin

                    rx_valid   <= 1'b0;
                    rx_counter <= 9'd0;
                    bit_idx    <= 3'd0;

                    if (rx_sync == 1'b0) begin
                        state      <= STATE_START;
                        rx_counter <= 9'd0;
                    end

                end


                // --------------------------------
                // START BIT VALIDATION
                // --------------------------------
                STATE_START: begin

                    if (rx_counter == HALF_BIT - 1) begin

                        rx_counter <= 9'd0;

                        if (rx_sync == 1'b0) begin
                            // Valid start bit
                            state <= STATE_DATA;
                        end else begin
                            // False start / noise
                            state <= STATE_IDLE;
                        end

                    end else begin

                        rx_counter <= rx_counter + 1'b1;

                    end

                end


                // --------------------------------
                // DATA
                // --------------------------------
                STATE_DATA: begin

    if (rx_counter == CLKS_PER_BIT - 1) begin

        data_reg[bit_idx] <= rx_sync;
        rx_counter <= 9'd0;

        if (bit_idx == 3'd7) begin
            bit_idx <= 3'd0;
            state   <= STATE_STOP;
        end else begin
            bit_idx <= bit_idx + 3'd1;
        end

    end else begin

        rx_counter <= rx_counter + 1'b1;

    end

end


                // --------------------------------
                // STOP
                // --------------------------------
                STATE_STOP: begin

                  

    if (rx_counter == CLKS_PER_BIT - 1) begin

        rx_counter <= 9'd0;

        if (rx_sync == 1'b1) begin

            // Valid stop bit
            rx_data  <= data_reg;
            rx_valid <= 1'b1;
            state    <= STATE_IDLE;

        end else begin

            // Framing error
            state    <= STATE_IDLE;

        end

    end else begin

        rx_counter <= rx_counter + 1'b1;

    end

end

                


                default: begin

                    state      <= STATE_IDLE;
                    rx_counter <= 9'd0;

                end

            endcase

        end

    end

endmodule