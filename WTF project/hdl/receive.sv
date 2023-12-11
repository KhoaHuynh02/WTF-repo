`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// // assuming that the information comes in at 12khz at 8 bits depth
// module receive #(
//     parameter BIT_DEPTH = /*16*/ 8,
//     parameter TIMING_ERROR = 30,
//     parameter SYNC_LO = 400,
//     parameter SYNC_HI = 600,
//     parameter SYNC_PERIOD = SYNC_LO + SYNC_HI,
//     parameter SEND_LO = 400,
//     parameter SEND_ZERO = 200,
//     parameter SEND_ONE = 400,
//     parameter SEND_ZERO_PERIOD = SEND_LO + SEND_ZERO,
//     parameter SEND_ONE_PERIOD = SEND_LO + SEND_ONE
// )
// (
//     input wire clk_in,
//     input wire rst_in,
//     input wire reading_in,
//     output logic valid_out,
//     output logic [7:0] data_out
// );
//     localparam IDLE = 0;
//     localparam SYNC = 1;
//     localparam RECEIVE = 2;

//     logic [1:0] state = IDLE;
//     logic [BIT_DEPTH-1:0] audio_buffer = 0;
//     logic [$clog2(SYNC_PERIOD)-1:0] period = 0;
//     logic [$clog2(BIT_DEPTH)-1:0] bits_receive = 0;

//     always_ff @(posedge clk_in) begin
//         if (rst_in) begin
//             state <= IDLE;
//             audio_buffer <= 0;
//             period <= 0;
//             bits_receive <= 0;
//             valid_out <= 0;
//             data_out <= 0;
//         end else begin
//             case(state)
//                 IDLE: begin
//                     // Keeps listening for SYNC signal
//                     period <= (reading_in == 1'b0) ? period + 1 : 0;
//                     // Discover a low sync signal
//                     if(period >= SYNC_LO - TIMING_ERROR && period <= SYNC_LO + TIMING_ERROR)begin
//                         if(reading_in == 1'b1) begin
//                             period <= 0;
//                             state <= SYNC;
//                         end
//                     end
//                 end

//                 SYNC: begin
//                     // Keeps listening for SYNC_HI signal

//                     // Once period crosses the SYNC_HI threshold
//                     if (period >= SYNC_HI - TIMING_ERROR && period <= SYNC_HI + TIMING_ERROR) begin
//                         state <= RECEIVE;
//                         audio_buffer <= 0;
//                         period <= 0;
//                         bits_receive <= 0;
//                         valid_out <= 0;
//                     end else begin
//                         // Keeps on incrementing
//                         if(reading_in == 1'b1) begin
//                             period <= period + 1;
//                         end
//                         // If the streak was broken reset back to IDLE
//                         else begin
//                             state <= IDLE;
//                             period <= 0;
//                             valid_out <= 0;
//                         end
//                     end
//                 end

//                 RECEIVE_LOW: begin
//                     if(bits_receive == WIDTH) begin
                    
//                     end
//                     period <= period + 1;

//                 end
//             endcase
//         end
//     end
// endmodule

`default_nettype wire