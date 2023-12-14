`timescale 1ns / 1ps
`default_nettype none

module rx #( 
    parameter SBD = 800,  // Sync burst duration.
    parameter SSD = 800,  // Sync silence duration.
    parameter BBD = 400,  // Bit burst duration.
    parameter BSD0 = 200,  // Bit silence duration (for 0).
    parameter BSD1 = 400,  // Bit silence duration (for 1).
    parameter MARGIN = 50,  // The +/- of your signals.
    parameter WIDTH = 8 // The bit depth of the output
) ( input wire clk_in,  // Clock in (98.3 MHz).
    input wire rst_in,  // Reset in.
    input wire signal_in,  // Signal in.
    output logic [WIDTH-1:0] code_out,  // Where to place code once captured.
    output logic new_code_out,  // Single-cycle indicator that new code is present!
    output logic [2:0] error_out,  // Output error codes for debugging.
    output logic [3:0] state_out  // Current state out (helpful for debugging).
);
  logic [31:0] signal_counter;
  typedef enum {IDLE=0, SH=1, SL=2, DH=3, DL=4, F0=5, F1=6, CHECK=7,DATA=8} states;
 
  current_counter mcc( .clk_in(clk_in),
                        .rst_in(rst_in),
                        .signal_in(signal_in),
                        .tally_out(signal_counter));
 
  states state;  // State of system!
 
  assign state_out = state;

  logic [WIDTH-1:0] building_code_out;
  logic [15:0] bit_out_count;

  logic light_on;
  assign light_on = signal_in;
 
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= IDLE;
      code_out <= 0;
      new_code_out <= 0;
      error_out <= 0;
      bit_out_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          new_code_out <= 0;
           // If light turns on, then move to SH.
          if (light_on) begin
            state <= SH;
            bit_out_count <= 0;
          end
        end
        // See if the light is on for the right amount of time. If so, move to SL.
        SH: begin
          // Light off at the correct interval.
          if (~light_on && (signal_counter >= SBD - MARGIN && signal_counter <= SBD + MARGIN)) begin
            state <= SL;
          // Light on for too long or light turned off prematurely. 
          end else if (signal_counter > SBD + MARGIN || ~light_on) begin
            state <= IDLE;
          end
        end
        SL: begin
          // Light turns back on at the correct time. Move to DH.
          if (light_on && (signal_counter >= SSD - MARGIN && signal_counter <= SSD + MARGIN)) begin
            state <= DH;
          // Light stays off for too long or light turns back on too early. 
          end else if (signal_counter > SSD + MARGIN || light_on) begin
            state <= IDLE;
          end
        end
        DH: begin
          // Light turns off at the correct time.
          if (~light_on && (signal_counter >= BBD - MARGIN && signal_counter <= BBD + MARGIN)) begin
            state <= DL;
          // Light is on for too long, or the light turns off too early.
          end else if (signal_counter > BBD + MARGIN || ~light_on) begin
            state <= IDLE;
          end
        end
        DL: begin
          // Light on. 
          if (light_on) begin
            // Light on in interval for 0. Move to F0.
            if (signal_counter >= BSD0 - MARGIN && signal_counter <= BSD0 + MARGIN) begin
              state <= F0;
            // Light on in interval for 1. Move to F1.
            end else if (signal_counter >= BSD1 - MARGIN && signal_counter <= BSD1 + MARGIN) begin
              state <= F1;
            // Light on in invalid interval. Return to IDLE.
            end else begin
              state <= IDLE;
            end
          // Light off for too long to be a 1 or 0. Return to IDLE.
          end else if (signal_counter > BSD1 + MARGIN) begin
            state <= IDLE;
          end
        end
        F0: begin
          // Add the zero.
          building_code_out <= building_code_out << 1 | 1'b0;
          bit_out_count <= bit_out_count + 1;
          state <= CHECK;
        end
        F1: begin
          // Add the one.
          building_code_out <= building_code_out << 1 | 1'b1;
          bit_out_count <= bit_out_count + 1;
          state <= CHECK;
        end
        CHECK: begin
          // Have all the bits, move to send.
          if (bit_out_count == WIDTH) begin
            state <= DATA;
          // Don't have all the bits, wait for more bits.
          end else begin
            state <= DH;
          end 
        end
        DATA: begin
          new_code_out <= 1;
          code_out <= building_code_out;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule

module current_counter
  ( input wire clk_in, //clock in
    input wire rst_in, //reset in
    input wire signal_in, //signal to be monitored
    output logic [31:0] tally_out //tally of how many cycles signal in has been at its current value
  );

    logic state;

    always_ff @(posedge clk_in) begin
        state <= signal_in;
        if (rst_in) begin
            tally_out <= 0;
        end else begin
            if (state != signal_in) begin
                tally_out <= 0;
            end else begin
                tally_out <= tally_out + 1;
            end
        end
    end
endmodule

`default_nettype none