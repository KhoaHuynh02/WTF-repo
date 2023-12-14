`timescale 1ns / 1ps
`default_nettype none

module tx #( 
    parameter SBD = 800,  // Sync burst duration.
    parameter SSD = 800,  // Sync silence duration.
    parameter BBD = 400,  // Bit burst duration.
    parameter BSD0 = 200,  // Bit silence duration (for 0).
    parameter BSD1 = 400,  // Bit silence duration (for 1).
    parameter WIDTH = 8 // The bit depth of the output
) ( input wire clk_in,  // Clock in (98.3 MHz).
    input wire rst_in,  // Reset in.
    input wire valid_in,  // Valid signal
    input wire [WIDTH-1:0] audio_in, // Audio in
    output logic out, // Signal out
    output logic busy // Code being sent
);

    typedef enum {IDLE=0, SH=1, SL=2, DH=3, F0=4, F1=5, WAIT=6} states;

    states state;

    logic [WIDTH-1:0] buffer;
    logic [15:0] signal_counter;
    logic [$clog2(WIDTH):0] to_send;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= IDLE;
            buffer <= 0;
            signal_counter <= 0;
            to_send <= 0;
            out <= 0;
            busy <= 0;
        end else begin
            case(state)
                IDLE: begin
                    if (valid_in) begin
                        state <= SH;
                        buffer <= audio_in;
                        signal_counter <= 0;
                        to_send <= WIDTH;
                        out <= 1;
                        busy <= 1;
                    end
                end

                SH: begin
                    signal_counter <= signal_counter + 1;
                    if (signal_counter == SBD-1) begin
                        state <= SL;
                        out <= 0;
                        signal_counter <= 0;
                    end
                end

                SL: begin
                    signal_counter <= signal_counter + 1;
                    if (signal_counter == SSD-1) begin
                        state <= DH;
                        out <= 1;
                        signal_counter <= 0;
                    end
                end

                DH: begin
                    signal_counter <= signal_counter + 1;
                    if (to_send == 0) begin
                        state <= WAIT;
                        out <= 1;
                        signal_counter <= 0;
                    end else begin
                        if (signal_counter == BBD-1) begin
                            out <= 0;
                            signal_counter <= 0;
                            if (~buffer[to_send-1]) begin
                                state <= F0;
                            end else begin
                                state <= F1;
                            end
                        end
                    end
                end

                F0: begin
                    signal_counter <= signal_counter + 1;
                    if (signal_counter == BSD0-1) begin
                        state <= DH;
                        out <= 1;
                        signal_counter <= 0;
                        to_send <= to_send - 1;
                    end
                end

                F1: begin
                    signal_counter <= signal_counter + 1;
                    if (signal_counter == BSD1-1) begin
                        state <= DH;
                        out <= 1;
                        signal_counter <= 0;
                        to_send <= to_send - 1;
                    end
                end

                WAIT: begin
                    signal_counter <= signal_counter + 1;
                    if (signal_counter == BBD-1) begin
                        state <= IDLE;
                        out <= 0;
                        signal_counter <= 0;
                        busy <= 0;
                    end
                end
            endcase
        end
    end
endmodule

`default_nettype wire