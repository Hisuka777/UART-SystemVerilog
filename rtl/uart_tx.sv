module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       baud_tick,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       tx_busy
);

    // Align the start-bit edge to the free-running baud generator.
    typedef enum logic [2:0] {
        STATE_IDLE      = 3'd0,
        STATE_WAIT_BAUD = 3'd1,
        STATE_START     = 3'd2,
        STATE_DATA      = 3'd3,
        STATE_STOP      = 3'd4
    } state_t;

    state_t state;

    logic [7:0] data_reg;
    logic [2:0] bit_idx;

    always_ff @(posedge clk) begin
        if (rst) begin
            state    <= STATE_IDLE;
            tx       <= 1'b1;
            tx_busy  <= 1'b0;
            bit_idx  <= 3'd0;
            data_reg <= 8'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    bit_idx <= 3'd0;

                    if (tx_start) begin
                        data_reg <= tx_data;
                        tx_busy  <= 1'b1;
                        // Do not assert the start bit until a baud boundary.
                        state    <= STATE_WAIT_BAUD;
                    end
                end

                // Hold serial idle HIGH and busy HIGH while waiting for the
                // next baud boundary. The START state's registered TX output
                // becomes LOW on the following clock edge; DATA will be
                // driven 434 clocks later at the next baud boundary.
                STATE_WAIT_BAUD: begin
                    tx <= 1'b1;
                    if (baud_tick) begin
                        state <= STATE_START;
                    end
                end

                STATE_START: begin
                    tx <= 1'b0;

                    if (baud_tick) begin
                        state <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    tx <= data_reg[bit_idx];

                    if (baud_tick) begin
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= STATE_STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                        end
                    end
                end

                STATE_STOP: begin
                    tx <= 1'b1;

                    if (baud_tick) begin
                        state   <= STATE_IDLE;
                        tx_busy <= 1'b0;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule