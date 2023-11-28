`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module fir_module #(
    parameter WIDTH = 16,
    parameter TAPS = 30,
    // pass band frequency 0.125 of fs
    // stop band frequency 0.200 of fs
    parameter OUT_WIDTH = 16 // we want to grab 16 bits out of the 32 bits computed value
) (
    input wire clk,
    input wire rst,
    input wire enable, // May come in a different frequency (i.e. 3MHZ, 780KHZ, etc) so need internal logic to detect edge
    input wire signed [WIDTH-1:0] data_in,
    output logic valid_out,
    output logic signed [OUT_WIDTH-1:0] out
);
    logic [WIDTH-1:0] delay_buffer [TAPS-1:0];
    logic [OUT_WIDTH-1:0] accumulator [TAPS-1:0];
    /*
    configure tap values here
    */
    // logic signed [WIDTH-1:0] taps[0:TAPS-1] = 
    parameter [0:WIDTH*TAPS-1] TAPS_ARRAY = {
        // 16'sd78,
        // 16'sd4,
        // -16'sd195,
        // -16'sd419,
        // -16'sd391,
        // 16'sd52,
        // 16'sd669,
        // 16'sd850,
        // 16'sd127,
        // -16'sd1202,
        // -16'sd1958,
        // -16'sd823,
        // 16'sd2525,
        // 16'sd6827,
        // 16'sd9845,
        // 16'sd9845,
        // 16'sd6827,
        // 16'sd2525,
        // -16'sd823,
        // -16'sd1958,
        // -16'sd1202,
        // 16'sd127,
        // 16'sd850,
        // 16'sd669,
        // 16'sd52,
        // -16'sd391,
        // -16'sd419,
        // -16'sd195,
        // 16'sd4,
        // 16'sd78
        
        -16'sd424,
        16'sd997,
        16'sd2537,
        16'sd295,
        -16'sd802,
        16'sd1060,
        -16'sd363,
        -16'sd783,
        16'sd1535,
        -16'sd1023,
        -16'sd817,
        16'sd2849,
        -16'sd3089,
        -16'sd844,
        16'sd18470,
        16'sd18470,
        -16'sd844,
        -16'sd3089,
        16'sd2849,
        -16'sd817,
        -16'sd1023,
        16'sd1535,
        -16'sd783,
        -16'sd363,
        16'sd1060,
        -16'sd802,
        16'sd295,
        16'sd2537,
        16'sd997,
        -16'sd424};
    logic [$clog2(TAPS):0] valid_counter; // in the case of a reset make sure the circular buffer is 
                                          //filled up before telling the next module data is ready
    /*
    Will need to have enable happen on one rising of clk_m edge (98 MHZ) since the clk is way faster than enable
    */
    logic enable_edge;
    logic old_edge;
    logic new_edge;
    assign enable_edge = new_edge && ~old_edge; // detect an enable step

    always_ff @(posedge clk) begin
        new_edge <= enable;
        old_edge <= new_edge;
    end
    
    /* Circular buffer stage*/
    always_ff @(posedge clk) begin
        if(rst) begin
            valid_counter <= 0;
            for(int k = 0; k < TAPS; k = k + 1) begin
                delay_buffer[k] <= 0;
            end
        end else begin 
            if(enable_edge) begin
                for(int k = 0; k < TAPS; k = k + 1) begin
                    valid_counter <= (valid_counter == TAPS) ? valid_counter: valid_counter + 1;
                    if(k == 0) begin
                        delay_buffer[k] <= data_in;
                    end else begin
                        delay_buffer[k] <= delay_buffer[k-1];
                    end
                end 
            end
        end 
    end


    /* Multiply and Add stage*/
    always_ff @(posedge clk) begin
        if(rst) begin
            for(int m = 0; m < TAPS; m = m + 1) begin
                accumulator[m] <= 0;
            end
            valid_counter <= 0;
        end else begin
            if(enable_edge) begin
                for(int m = 0; m < TAPS; m = m + 1) begin
                    if(m == 0) begin 
                        accumulator[0] <= data_in * TAPS_ARRAY[0:WIDTH-1];
                    end else begin
                        accumulator[m] <= delay_buffer[m] * TAPS_ARRAY[m*WIDTH +: WIDTH];
                    end
                    valid_counter <= (valid_counter == TAPS) ? valid_counter: valid_counter + 1;
                end
            end
        end
    end 

    logic [31:0] temp_sum; // Temporary variable to accumulate the sum
    logic [31:0] sum_acc;
    integer i;
    always_ff @(posedge clk) begin
        if(enable_edge) begin
            sum_acc = 0;
            for(i = 0; i < TAPS; i = i + 1) begin
                sum_acc = sum_acc + accumulator[i];
            end
            temp_sum <= sum_acc;
            valid_counter <= (valid_counter == TAPS) ? valid_counter: valid_counter + 1;
        end
        if(rst) begin
            temp_sum <= 0;
            valid_counter <= 0;
        end
    end
    assign out = temp_sum[23:8]; // [31 ------------24 23----------- 8 7 ----------- 0]
    assign valid_out = (valid_counter == TAPS);

endmodule

`default_nettype wire