`timescale 1ns / 1ps
`default_nettype none

module destroy_block(
    input wire clk_in,
    input wire rst_in,
    input wire start,
    input wire request,
    input wire [15:0][7:0] block_in,
    output logic [7:0] result_out,
    output logic valid_out
);

    typedef enum {IDLE=0, STREAM=1} block_state;

    block_state state = IDLE;

    logic [4:0] current_block;
    logic [15:0][7:0] buffer;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            current_block <= 0;
            result_out <= 0;
            state <= IDLE;
        end else begin
            case(state)
                IDLE: begin
                    if (start) begin
                        state <= STREAM;
                        current_block <= 0;
                        buffer <= block_in;
                    end
                end

                STREAM: begin
                    if (current_block == 16) begin
                        state <= IDLE;
                        result_out <= 0;
                    end else begin
                        if (request) begin
                            valid_out <= 1;
                            result_out <= buffer[current_block];
                            current_block <= current_block + 1;
                        end else begin
                            valid_out <= 0;
                        end
                    end
                end
            endcase
        end
    end
endmodule

`default_nettype wire