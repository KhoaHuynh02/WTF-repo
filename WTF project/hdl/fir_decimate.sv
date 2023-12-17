`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// pass band frequency 0.25 of nyquist and stop band frequency 0.25 of fs
module fir_decimate
#(
    parameter DATA_WIDTH = 16 // data width is 16 to account for overflows
)
(
    input wire clk,                                     // System clock
    input wire rst,                                     // Reset signal
    input wire single_valid_in,                         // Single cycle valid in (freqeuncy of incoming signal)
    input wire [4:0] right_shift,                       // How much to scale down the output of FIR
    input wire signed [DATA_WIDTH-1:0] data_in,         // Signed data in
    output logic fad_valid_out,                         // Single cycle indicating output data is ready to consume
    output logic signed [DATA_WIDTH-1:0] fad_data_out   // Data out
);

    logic fir_valid_out;
    logic signed [DATA_WIDTH-1:0] fir_out;
    // FSM fir module
    fir fir_module
          ( .clk(clk),
            .rst(rst),
            .right_shift(right_shift),
            .single_valid_in(single_valid_in),
            .data_in(data_in),
            .valid_out(fir_valid_out),
            .data_out(fir_out)
          );
    decimate #(
      .WIDTH(DATA_WIDTH)
    )
    decimate(
      .clk(clk),
      .rst(rst),
      .valid_in(fir_valid_out),
      .data_in(fir_out),
      .valid_out(fad_valid_out), 
      .data_out(fad_data_out)
    );
endmodule


`default_nettype wire