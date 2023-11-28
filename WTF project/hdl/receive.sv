`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// assuming that the information comes in at 12khz at 8 bits depth
module receive (
    input wire clk_in,
    input wire rst_in,
    input wire record_done,
    input wire [7:0] audio_in,
    input wire audio_valid_in,
    output logic valid_out,
    output logic out
);

endmodule

`default_nettype wire