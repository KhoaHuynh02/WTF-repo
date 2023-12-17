`timescale 1ns / 1ps
`default_nettype none

//
//
// - Parameters:
//   -
// - Results:
//   -
module decipher_round(
    // Controls.
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire start,  // Indicates a new valid block has been passed in.

    // Inputs.
    input wire [127:0] block_in,  // The new block to encrypt.
    input wire [127:0] key_in,  // The key to use for AES (with key expansion already applied).

    // Outputs.
    output logic [127:0] block_out,  // The block with the shifted rows.
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

    // `block_in` is saved here, just in case it changes.
    logic [127:0] saved_block_in;

    // The result is saved here while being computed, then
    // placed in `block_out` once complete.
    logic [127:0] saved_output;
    
    logic shift_rows_start;
    logic [127:0] shift_rows_result;
    logic shift_rows_complete;
    inv_shift_rows inv_shift_rows_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .start(shift_rows_start),  // Indicates a new valid block has been passed in.
        .block_in(saved_block_in),  // The new block whose rows should be shifted.
        .result_out(shift_rows_result),  // The block with the shifted rows.
        .valid_out(shift_rows_complete)  // Goes high for one cycle to indicate that `result_out` is read.
    );

    // logic sub_bytes_start;
    logic [127:0] sub_bytes_result;
    logic sub_bytes_complete;
    inv_sub_bytes inv_sub_bytes_inst(
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .new_block_in(shift_rows_complete),  // Indicates a new valid block has been passed in.
        .block_in(shift_rows_result),  // The new block whose bytes should be substituted.
        .inv_subbed_block_out(sub_bytes_result),  // The block with the substituted blocks.
        .valid_out(sub_bytes_complete)  // Goes high for one cycle to indicate that `subbed_block_out` is complete.
    );

    logic [127:0] add_round_key_result;
    logic [127:0] add_round_key_key_in;
    logic add_round_key_complete;
    add_round_key add_round_key_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .start(sub_bytes_complete),  // Indicates a new valid block has been passed in.
        .round_key_in(add_round_key_key_in),
        .block_in(sub_bytes_result),  // The new block whose bytes should have the key applied/XORed.
        .result_out(add_round_key_result),  // The block with the XORed blocks.
        .valid_out(add_round_key_complete)  // Goes high for one cycle to indicate that `result_out` is ready.
    );

    logic [127:0] mix_cols_result;
    logic mix_cols_complete;
    inv_mix_cols inv_mix_cols_inst(
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .start(add_round_key_complete),  // Indicates a new valid block has been passed in.
        .block_in(add_round_key_result),  // The new block whose columns should be mixed.
        .result_out(mix_cols_result),  // The block with the mixed columns.
        .valid_out(mix_cols_complete)  // Goes high for one cycle to indicate that `result_out` is read.
    );

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            state <= WAIT_FOR_START;
            block_out <= 128'b0;

            shift_rows_start <= 0;

            block_complete <= 0;
        end else begin
            case (state)
                // Resting state; waiting for input.
                WAIT_FOR_START: begin
                    block_complete <= 0;
                    // New input received; start the round.
                    if (start) begin
                        saved_block_in <= block_in;
                        add_round_key_key_in <= key_in;

                        state <= ROUND;

                        // Start the chain of operations, beginning with `sub_byte`,
                        // then `shift_rows`, `mix_cols`, and ending with `add_round_key`.
                        shift_rows_start <= 1;

                        block_out <= 128'b0;
                    end
                end
                ROUND: begin
                    shift_rows_start <= 0;

                    // All calculations complete. Output.
                    if (mix_cols_complete) begin
                        block_out <= mix_cols_result;
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
