
module rx_synchronizer (
    input  logic clk,
    input  logic rst,
    input  logic rx,
    output logic rx_sync
);

logic sync_ff1;
logic sync_ff2;

always_ff @(posedge clk) begin
    if (rst) begin
        sync_ff1 <= 1'b1;
        sync_ff2 <= 1'b1;
    end
    else begin
        sync_ff1 <= rx;
        sync_ff2 <= sync_ff1;
    end
end

assign rx_sync = sync_ff2;

endmodule