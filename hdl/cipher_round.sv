`timescale 1ns / 1ps
`default_nettype none

//
//
// - Parameters:
//   -
// - Results:
//   -
module cipher_round(
    // Controls.
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire start,  // Indicates a new valid block has been passed in.

    // Inputs.
    input wire [127:0] block_in,  // The new block to encrypt.
    input wire [127:0] key_in,  // The key to use for AES.
    input wire [31:0] rcon_in,

    // Outputs.
    output logic [127:0] block_out,  // The block with the shifted rows.
    output logic [127:0] key_out,  // The key that was used.
    output logic block_complete  // Goes high for one cycle to indicate that `block_out` is done.
);

    // The three possible states of the FSM.
    //
    // - WAIT_FOR_START: Resting state; waiting for input.
    // - SHIFT_ROWS: Actively shifting rows/bytes.
    // - OUTPUT: Keeps `valid_out` true for one cycle; only
    //   remains in this state for one cycle.
    typedef enum {
        WAIT_FOR_START,
        ROUND,
        OUTPUT
    } aes_round_state;

    // The current state of the FSM.
    aes_round_state state = WAIT_FOR_START;

    // The current round of AES.
    logic [3:0] AES_round = 0;

    // `block_in` is saved here, just in case it changes.
    logic [127:0] saved_block_in;

    // The result is saved here while being computed, then
    // placed in `block_out` once complete.
    logic [127:0] saved_output;

    logic sub_bytes_start;
    logic [127:0] sub_bytes_result;
    logic sub_bytes_complete;
    sub_bytes sub_bytes_inst(
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .new_block_in(sub_bytes_start),  // Indicates a new valid block has been passed in.
        .block_in(saved_block_in),  // The new block whose bytes should be substituted.
        .subbed_block_out(sub_bytes_result),  // The block with the substituted blocks.
        .valid_out(sub_bytes_complete)  // Goes high for one cycle to indicate that `subbed_block_out` is complete.
    );

    logic [127:0] shift_rows_result;
    logic shift_rows_complete;
    shift_rows shift_rows_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .start(sub_bytes_complete),  // Indicates a new valid block has been passed in.
        .block_in(sub_bytes_result),  // The new block whose rows should be shifted.
        .result_out(shift_rows_result),  // The block with the shifted rows.
        .valid_out(shift_rows_complete)  // Goes high for one cycle to indicate that `result_out` is read.
    );

    logic [127:0] mix_cols_result;
    logic mix_cols_complete;
    mix_cols mix_cols_inst(
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .start(shift_rows_complete),  // Indicates a new valid block has been passed in.
        .block_in(shift_rows_result),  // The new block whose columns should be mixed.
        .result_out(mix_cols_result),  // The block with the mixed columns.
        .valid_out(mix_cols_complete)  // Goes high for one cycle to indicate that `result_out` is read.
    );

    logic key_expansion_start;
    logic [127:0] key_expansion_result;
    logic key_expansion_complete;
    key_expansion key_expansion_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .new_key_in(key_expansion_start),
        .key_in(key_in),
        .rcon_in(rcon_in),
        .expanded_key_out(key_expansion_result),
        .valid_out(key_expansion_complete)
    );

    // NOTE: ASSUMES THAT KEY EXPANSION HAS FINISHED BY THE TIME THIS IS CALLED
    // (i.e., before `mix_cols_complete` is true).
    logic [127:0] add_round_key_result;
    logic add_round_key_complete;
    add_round_key add_round_key_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .start(mix_cols_complete),  // Indicates a new valid block has been passed in.
        .round_key_in(key_out),  // The key.
        .block_in(mix_cols_result),  // The new block whose bytes should have the key applied/XORed.
        .result_out(add_round_key_result),  // The block with the XORed blocks.
        .valid_out(add_round_key_complete)  // Goes high for one cycle to indicate that `result_out` is ready.
    );

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            state <= WAIT_FOR_START;
            block_out <= 128'b0;
            key_out <= 0;

            sub_bytes_start <= 0;
            key_expansion_start <= 0;
            block_complete <= 0;
        end else begin
            case (state)
                // Resting state; waiting for input.
                WAIT_FOR_START: begin
                    block_complete <= 0;
                    // New input received; start the round.
                    if (start) begin
                        saved_block_in <= block_in;

                        state <= ROUND;

                        // Start the chain of operations, beginning with `sub_byte`,
                        // then `shift_rows`, `mix_cols`, and ending with `add_round_key`.
                        sub_bytes_start <= 1;

                        // Start the key expansion module.
                        key_expansion_start <= 1;

                        block_out <= 128'b0;
                        key_out <= 0;
                    end
                end
                ROUND: begin
                    sub_bytes_start <= 0;
                    key_expansion_start <= 0;

                    if (key_expansion_complete) begin
                        key_out <= key_expansion_result;
                    end


                    // All calculations complete. Output.
                    if (add_round_key_complete) begin
                        block_out <= add_round_key_result;
                        block_complete <= 1;
                        state <= OUTPUT;
                    end
                end
                // Only stay in `OUTPUT` state for one cycle, then reset.
                OUTPUT: begin
                    block_complete <= 0;
                    state <= WAIT_FOR_START;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
