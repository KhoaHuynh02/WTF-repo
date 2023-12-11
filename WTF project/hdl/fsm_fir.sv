`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module fir_module #(
    parameter WIDTH = 16,
    parameter TAPS = 30,
    // pass band frequency 0.125 of fs and stop band frequency 0.200 of fs
    parameter OUT_WIDTH = 32 // we want to grab 16 bits out of the 32 bits computed value
) (
    input wire clk,
    input wire rst,
    input wire single_valid_in, // Single cycle signal indicating the frequency the input signal comes in
    input wire signed [WIDTH-1:0] data_in, 
    output logic valid_out,
    output logic signed [OUT_WIDTH/2-1:0] data_out
);
    
    /*
    configure tap values here
    */
    localparam [WIDTH*TAPS-1:0] coef = {
        16'sd317,
        16'sd775,
        16'sd240,
        -16'sd1557,
        -16'sd2385,
        -16'sd691,
        16'sd858,
        -16'sd453,
        -16'sd1714,
        16'sd439,
        16'sd2018,
        -16'sd1413,
        -16'sd3522,
        16'sd4200,
        16'sd15349,
        16'sd15349,
        16'sd4200,
        -16'sd3522,
        -16'sd1413,
        16'sd2018,
        16'sd439,
        -16'sd1714,
        -16'sd453,
        16'sd858,
        -16'sd691,
        -16'sd2385,
        -16'sd1557,
        16'sd240,
        16'sd775,
        16'sd317 
        };


    localparam IDLE = 0;
    localparam SUM_ADD = 1;
    localparam DONE = 2;

    logic [2:0] state = IDLE;

    logic signed [OUT_WIDTH - 1:0] accumulator = 0;
    logic [$clog2(TAPS)-1:0] valid_counter = 0;
    logic signed [WIDTH-1:0] delay_buffer [TAPS-1:0];
    
    always_ff @(posedge clk) begin
        if(rst) begin
            valid_counter <= 0;
            state <= IDLE;
            accumulator <= 0;  
            // delay_buffer <= {delay_buffer[TAPS-1:1],0};
            for(int k = 0; k < TAPS; k = k + 1) begin
                delay_buffer[k] <= 0;
            end
        end else begin 
            if(state == IDLE) begin
                if(single_valid_in) begin
                    state <= SUM_ADD;
                    accumulator <= 0;
                    valid_counter <= 0;

                    // shift new data in
                    // delay_buffer <= {delay_buffer[TAPS-1:1],data_in};
                    delay_buffer[0] <= data_in;
                    for(int k = 1; k < TAPS; k = k + 1) begin
                        delay_buffer[k] <= delay_buffer[k-1];
                    end
                end
            end
            else if(state == SUM_ADD) begin
                if(valid_counter < TAPS) begin
                    
                    valid_counter <= valid_counter + 1;
                    if(valid_counter == TAPS - 1) begin
                        state <= DONE;
                        valid_out <= 1'b1;
                        valid_counter <= 0;
                    end
                    accumulator <= accumulator + delay_buffer[valid_counter] * $signed(coef[valid_counter*WIDTH +: WIDTH]);
                    // accumulator <= accumulator + delay_buffer[valid_counter] * $signed(coef[valid_counter]);
                end
            end
            else if(state == DONE) begin
                state <= IDLE;
                valid_out <= 1'b0;
                // data_out <= accumulator[23:8];
                data_out <= accumulator[31:16];
                // data_out <= accumulator;
            end
        end 
    end

endmodule

`default_nettype wire