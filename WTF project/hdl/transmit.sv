`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// assumming that the information comes in at 12khz at 16 bits depth
module transmit #(parameter BIT_DEPTH = 16)
(
    input wire clk_in, // 98.3 MHZ ~ 10ns
    input wire rst_in,
    input wire [7:0] audio_in, // audio data in
    input wire audio_valid_in, //12 khz
    output logic valid_out,
    output logic out
);

    localparam IDLE = 0;
    localparam SYNC = 1;
    localparam SEND = 2;

    localparam SYNC_LO = 400;
    localparam SYNC_HI = 600;
    localparam SYNC_PERIOD = SYNC_LO + SYNC_HI;

    localparam SEND_LO = 200;
    localparam SEND_ZERO = 200;
    localparam SEND_ONE = 600;
    localparam SEND_ZERO_PERIOD = SEND_LO + SEND_ZERO;
    localparam SEND_ONE_PERIOD = SEND_LO + SEND_ONE;

    logic [1:0] state = IDLE;
    logic [BIT_DEPTH-1:0] audio_buffer = 0;
    logic [$clog2(SYNC_PERIOD)-1:0] period = 0;
    logic [$clogs(BIT_DEPTH)] sent_bits = 0;

    always_ff(posedge clk_in) begin
        if (rst_in) begin
            state <= IDLE;
            audio_buffer = 0;
            period <= 0;
            sent_bits <= 0;
            valid_out <= 0;
            out <= 0;
        end else begin
            case(state)
                IDLE: begin
                    if (audio_valid_in) begin
                        state <= SYNC;
                        audio_buffer <= audio_in;
                        period <= 0;
                        sent_bits <= BIT_DEPTH;
                        valid_out <= 1;
                        out <= 0;
                    end
                end

                SYNC: begin
                    period <= period + 1;
                    if (period == SYNC_LO) begin
                        out <= 1;
                    end else if (period == SYNC_PERIOD) begin
                        state <= SEND;
                        period <= 0;
                        out <= 0;
                    end
                end

                SEND: begin
                    period <= period + 1;
                    if (sent_bits == 0) begin
                        state <= IDLE;
                        valid_out <= 0;
                        out <= 0;
                    end else begin
                        if (period == SEND_LO) begin
                            out <= 1;
                        end else begin
                            if (audio_buffer[sent_bits-1] == 0) begin
                                if (period == SEND_ZERO_PERIOD) begin
                                    period <= 0;
                                    sent_bits <= sent_bits - 1;
                                    out <= 0;
                                end
                            end else begin
                                if (period == SEND_ONE_PERIOD) begin
                                    period <= 0;
                                    sent_bits <= sent_bits - 1;
                                    out <= 0;
                                end
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule

`default_nettype wire