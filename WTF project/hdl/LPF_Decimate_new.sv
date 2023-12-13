`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module fir_and_decimate_new
#(
    parameter DATA_WIDTH = 16
    // pass band frequency 0.25 of nyquist and stop band frequency 0.25 of fs
)
(
    input wire clk,
    input wire rst,
    input wire single_valid_in,
    input wire [3:0] right_shift,
    input wire signed [DATA_WIDTH-1:0] data_in,
    output logic fad_valid_out,
    output logic signed [DATA_WIDTH-1:0] fad_data_out
);

    logic fir_valid_out;
    logic signed [DATA_WIDTH-1:0] fir_out;
    // FSM fir module
    fir_module_new fir
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