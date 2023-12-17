`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module fir#(
    parameter TAPS = 30
)
(
    input wire clk,                                 // System clock
    input wire rst,                                 // Reset 
    input wire [4:0] right_shift ,                  // How much to scale down the ouput of LPF  
    input wire single_valid_in,                     // Single cycle data is valid
    input wire signed [15:0] data_in,               // Data coming in
    output logic valid_out,                         // Data is ready for consumption
    output logic signed [15:0] data_out             // LPF data
);
    
    /*
    configure tap values here
    */
    logic signed [16*TAPS-1:0] coef= {
        16'sd292,
        16'sd303,
        16'sd310,
        16'sd167,
        -16'sd140,
        -16'sd555,
        -16'sd947,
        -16'sd1133,
        -16'sd936,
        -16'sd244,
        16'sd930,
        16'sd2435,
        16'sd3997,
        16'sd5288,
        16'sd6019,
        16'sd6019,
        16'sd5288,
        16'sd3997,
        16'sd2435,
        16'sd930,
        -16'sd244,
        -16'sd936,
        -16'sd1133,
        -16'sd947,
        -16'sd555,
        -16'sd140,
        16'sd167,
        16'sd310,
        16'sd303,
        16'sd292
        };

    localparam IDLE = 0;
    localparam SUM_ADD = 1;
    localparam DONE = 2;

    logic [2:0] state = IDLE;

    // Buffer to store the calculated add and multiply
    logic signed [40:0] accumulator;
    logic signed [15:0] delay_buffer [TAPS-1:0];

    logic [$clog2(TAPS):0] valid_counter;
    logic signed [15:0] coef_vals;
    logic signed [15:0] delay_buff_val;

    always_ff @(posedge clk) begin
        if(rst) begin
            valid_counter <= 0;
            state <= IDLE;
            accumulator <= 0;  
            for(int k = 0; k < TAPS; k = k + 1) begin
                delay_buffer[k] <= 0;
            end
        end else begin 
            if(state == IDLE) begin
                if(single_valid_in) begin
                    state <= SUM_ADD;
                    accumulator <= 0;
                    valid_counter <= 0;
                    
                    // Shift new data in
                    delay_buffer[0] <= data_in; 
                    for(int k = 1; k < TAPS; k = k + 1) begin
                        // Shift the delay buffers back
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
                    accumulator <= $signed(accumulator) + $signed(delay_buffer[valid_counter]) * $signed(coef[valid_counter*16 +: 16]) ;
                end
            end
            else if(state == DONE) begin
                state <= IDLE;
                valid_out <= 1'b0;
                // Scale down the ouput of the FIR
                data_out <= accumulator >>> right_shift;
            end
        end 
    end

endmodule

`default_nettype wire