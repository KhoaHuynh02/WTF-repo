`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

function automatic [127:0] transpose(input [3:0][3:0][7:0] matrix_in);
    begin
        logic [3:0][3:0][7:0] transposed;

        transposed[1][0] = matrix_in[0][1];
        transposed[0][1] = matrix_in[1][0];

        transposed[2][0] = matrix_in[0][2];
        transposed[0][2] = matrix_in[2][0];

        transposed[3][0] = matrix_in[0][3];
        transposed[0][3] = matrix_in[3][0];

        transposed[2][1] = matrix_in[1][2];
        transposed[1][2] = matrix_in[2][1];

        transposed[3][1] = matrix_in[1][3];
        transposed[1][3] = matrix_in[3][1];

        transposed[3][2] = matrix_in[2][3];
        transposed[2][3] = matrix_in[3][2];

        transposed[0][0] = matrix_in[0][0];
        transposed[1][1] = matrix_in[1][1];
        transposed[2][2] = matrix_in[2][2];
        transposed[3][3] = matrix_in[3][3];

        transpose = transposed;
    end
endfunction

// NOTE: TAKES IN ROW MAJOR ORDER, AS IT CONVERTS INTERNALLY.
//
// - Parameters:
//   -
// - Results:
//   -
module key_expansion(
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire new_key_in,  // Indicates a new valid word has been passed in.
    input wire [3:0][31:0] key_in,  // The new word whose bytes should be substituted.
    input wire [31:0] rcon_in,
    output logic [127:0] expanded_key_out,  // The word with the substituted word.
    output logic valid_out  // Goes high for one cycle to indicate that `subbed_word_out` is complete.
);

    // 
    typedef enum {WAIT_FOR_KEY, ROTATE_AND_SUB, KEY_EXPANSION, OUTPUT, PAUSE} key_expansion_state;

    // The current state of the FSM.
    key_expansion_state state = WAIT_FOR_KEY;

    logic [3:0][31:0] saved_key;

    // The result is saved here while being computed, then
    // placed in `expanded_key_out` once complete.
    logic [3:0][31:0] expanded_key_internal;

    logic [31:0] rotated_and_subbed_key_word;
    logic rotate_and_sub_start;
    logic [31:0] rotate_and_sub_rcon_in;
    logic [31:0] rotate_and_sub_result;
    logic rotate_and_sub_complete;
    rotate_and_sub_key_word rotate_and_sub_key_word_inst(
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .new_word_in(rotate_and_sub_start),  // Indicates a new valid block has been passed in.
        .word_in(saved_key[0]),  // The key to expand. Column major form.
        .rcon_in(rotate_and_sub_rcon_in),  // The provided Rcon constant, as specified in AES protocol.
        .result_out(rotate_and_sub_result),  // The block with the shifted rows.
        .valid_out(rotate_and_sub_complete)  // Goes high for one cycle to indicate that `result_out` is read.
    );

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            valid_out <= 0;
            state <= WAIT_FOR_KEY;
            expanded_key_out <= 128'b0;
        end else begin
            case (state)
                // Resting state; waiting for input.
                WAIT_FOR_KEY: begin
                    valid_out <= 0;
                    // New input received; start grabbing the next byte;
                    if (new_key_in) begin
                        // Save the passed in word.
                        saved_key <= transpose(key_in);

                        expanded_key_internal <= 0;
                        valid_out <= 0;

                        rotate_and_sub_rcon_in <= rcon_in;
                        state <= ROTATE_AND_SUB;
                        rotate_and_sub_start <= 1;
                    end
                end
                ROTATE_AND_SUB: begin
                    rotate_and_sub_start <= 0;
                    if (rotate_and_sub_complete) begin
                        state <= KEY_EXPANSION;
                    end
                end
                KEY_EXPANSION: begin
                    expanded_key_internal[3] <= saved_key[3] ^ rotate_and_sub_result;

                    // saved_key[2] ^ expanded_key_internal[3]
                    expanded_key_internal[2] <=
                        saved_key[2]
                        ^ saved_key[3]
                        ^ rotate_and_sub_result;

                    // saved_key[1] ^ expanded_key_internal[2]
                    expanded_key_internal[1] <=
                        saved_key[1]
                        ^ saved_key[2]
                        ^ saved_key[3]
                        ^ rotate_and_sub_result;

                    // saved_key[0] ^ expanded_key_internal[1]
                    expanded_key_internal[0] <=
                        saved_key[0]
                        ^ saved_key[1]
                        ^ saved_key[2]
                        ^ saved_key[3]
                        ^ rotate_and_sub_result;
                    state <= OUTPUT;
                end
                OUTPUT: begin
                    expanded_key_out <= transpose(expanded_key_internal);
                    valid_out <= 1;
                    state <= PAUSE;
                end
                // Only stay in `PAUSE` state for one cycle, then reset.
                PAUSE: begin
                    valid_out <= 0;
                    state <= WAIT_FOR_KEY;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
