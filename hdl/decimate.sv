`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// for every DECIMATE_FACTOR (M) sample, keeps 1
module decimate #(
    parameter DECIMATE_FACTOR = 4,
    parameter WIDTH = 16
)
(
    input wire clk,
    input wire rst,
    input wire valid_in,
    input wire signed [WIDTH-1:0] data_in,
    output logic valid_out, // should be the frequency of valid_in/DECIMATE_FACTOR
    output logic signed [WIDTH-1:0]data_out
);

logic [$clog2(DECIMATE_FACTOR):0] counter;


// logic enable_edge;
// logic old_edge;
// logic new_edge;
// assign enable_edge = new_edge && ~old_edge; // detect an valid step

// always_ff @(posedge clk) begin
//     new_edge <= valid_in;
//     old_edge <= new_edge;
// end


always_ff @(posedge clk) begin
    if(rst) begin
        counter <= 0;
    end else begin
        counter <= (counter == DECIMATE_FACTOR) ? 0 : counter;
        if(valid_in) begin
            counter <= (counter == DECIMATE_FACTOR) ? 0 : counter + 1;
        end
        valid_out <= (counter == DECIMATE_FACTOR);
    end
end
assign data_out = valid_out ? data_in : data_out;
endmodule



`default_nettype wire