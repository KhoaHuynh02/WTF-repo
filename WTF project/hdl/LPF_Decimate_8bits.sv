`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module fir_and_decimate_8bits
#(
    parameter DATA_WIDTH = 8
    // pass band frequency 0.125 of fs and stop band frequency 0.200 of fs
)
(
    input wire clk,
    input wire rst,
    input wire single_valid_in,
    input wire signed [DATA_WIDTH-1:0] data_in,
    output logic fad_valid_out,
    output logic signed [DATA_WIDTH-1:0] fad_data_out
);

    logic fir_eight_valid_out;
    logic signed [7:0] fir_eight_out;
    // FSM fir module
    fir_module_8bits eight_bits_fir
          ( .clk(clk),
            .rst(rst),
            .single_valid_in(single_valid_in),
            .data_in(data_in),
            .valid_out(fir_eight_valid_out),
            .data_out(fir_eight_out)
          );

    logic first_stage_8bits_valid_out;
    logic signed [7:0] first_stage_8bits_out;
    decimate #(
      .WIDTH(8)
    )
    decimate_8bits(
      .clk(clk),
      .rst(rst),
      .valid_in(fir_eight_valid_out),
      .data_in(fir_eight_out),
      .valid_out(fad_valid_out), 
      .data_out(fad_data_out)
    );
endmodule


`default_nettype wire