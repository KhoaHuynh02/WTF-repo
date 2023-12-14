`timescale 1ns / 1ps
`default_nettype none

//
//
// - Parameters:
//   -
// - Results:
//   -
module decipher(
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire start,  // Indicates a new valid block has been passed in.
    input wire [127:0] block_in,  // The new block to encrypt.
    input wire [127:0] key_in,  // The key to use for decipher.
    output logic [127:0] result_out,  // The block with the shifted rows.
    output logic valid_out  // Goes high for one cycle to indicate that `result_out` is read.
);

    // The three possible states of the FSM.
    //
    // - WAIT_FOR_START: Resting state; waiting for input.
    // - SHIFT_ROWS: Actively shifting rows/bytes.
    // - OUTPUT: Keeps `valid_out` true for one cycle; only
    //   remains in this state for one cycle.
    typedef enum {WAIT_FOR_START, KEY_EXPANSION, ROUND, ROUND_WAIT, OUTPUT} decipher_state;

    // The current state of the FSM.
    decipher_state state = WAIT_FOR_START;

    // The current decipher round.
    logic [3:0] decipher_round_count = 0;

    // The current block, which may change over time. 
    logic [127:0] current_block;

    // The key, which will change over time.
    logic [127:0] current_key;

    // The result is saved here while being computed, then
    // placed in `result_out` once complete.
    logic [127:0] saved_output;

    // Key expansion module.
    logic key_expansion_start;
    logic [127:0] key_expansion_key_in;
    logic [31:0] key_expansion_rcon_in;
    logic [127:0] key_expansion_result;
    logic key_expansion_complete;
    key_expansion key_expansion_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .new_key_in(key_expansion_start),
        .key_in(key_expansion_key_in),
        .rcon_in(key_expansion_rcon_in),  // The Rcon for round 10.
        .expanded_key_out(key_expansion_result),
        .valid_out(key_expansion_complete)
    );

    // Shift rows module.
    logic shift_rows_start;
    logic [127:0] shift_rows_block_in;
    logic [127:0] shift_rows_result;
    logic shift_rows_complete;
    inv_shift_rows inv_shift_rows_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .start(shift_rows_start),  // Indicates a new valid block has been passed in.
        .block_in(shift_rows_block_in),  // The new block whose rows should be shifted.
        .result_out(shift_rows_result),  // The block with the shifted rows.
        .valid_out(shift_rows_complete)  // Goes high for one cycle to indicate that `result_out` is read.
    );

    // Sub bytes module.
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

    // Add round key module.
    logic [127:0] add_round_key_result;
    logic [127:0] add_round_key_key_in;
    logic add_round_key_complete;
    add_round_key add_round_key_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .start(sub_bytes_complete),  // Indicates a new valid block has been passed in.
        .round_key_in(keys[0]),
        // .round_key_in(add_round_key_key_in),  // The key.
        .block_in(sub_bytes_result),  // The new block whose bytes should have the key applied/XORed.
        .result_out(add_round_key_result),  // The block with the XORed blocks.
        .valid_out(add_round_key_complete)  // Goes high for one cycle to indicate that `result_out` is ready.
    );

    // Decipher round module.
    logic decipher_round_start;
    logic [127:0] decipher_round_block_in;
    logic [127:0] decipher_round_key_in;
    logic [127:0] decipher_round_block_out;
    logic [127:0] decipher_round_key_out;
    logic decipher_round_complete;
    decipher_round decipher_round_inst(
        // Controls.
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .start(decipher_round_start),

        // Inputs.
        .block_in(decipher_round_block_in),  // Indicates a new valid block has been passed in.
        .key_in(decipher_round_key_in),

        // Outputs.
        .block_out(decipher_round_block_out),  // The block with the substituted blocks.
        .block_complete(decipher_round_complete)  // Goes high for one cycle to indicate that `subbed_block_out` is complete.
    );

    logic [127:0] keys [10:0];
    logic [3:0] next_key_index;

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            state <= WAIT_FOR_START;
            result_out <= 128'b0;
            valid_out <= 0;
        end else begin
            case (state)
                // Resting state; waiting for input.
                WAIT_FOR_START: begin
                    valid_out <= 0;
                    // New input received; start XORing
                    if (start) begin
                        result_out <= 128'b0;

                        current_block <= block_in;

                        // Save the first key.
                        keys[0] <= key_in;
                        next_key_index <= 1;

                        // Get the rest of the keys.
                        key_expansion_key_in <= key_in;  // Start based off of the first key.
                        key_expansion_rcon_in <= 32'h01000000;
                        key_expansion_start <= 1;
                        state <= KEY_EXPANSION;
                    end
                end
                KEY_EXPANSION: begin
                    // Check if done with all key expansions--if so, carry out the
                    // first round of the deciphering, then move on to the other rounds.
                    if (next_key_index == 11) begin
                        // Initial round.
                        current_block <= current_block ^ keys[10];

                        // Initiate the rest of the rounds.
                        decipher_round_count <= 9;
                        state <= ROUND;
                    // Previous key expansion finished.
                    end else if (key_expansion_complete) begin
                        keys[next_key_index] <= key_expansion_result;
                        
                        // Start the next key expansion.
                        key_expansion_key_in <= key_expansion_result;
                        next_key_index <= next_key_index + 1;
                        key_expansion_start <= 1;

                        // Determine the rcon for the next key expansion.

                        // About to calculate key for rounds 1-8, inclusive.
                        if (next_key_index < 8) begin
                            key_expansion_rcon_in <= {8'h01 << next_key_index, 24'h000000};
                        // About to calculate key for round 9.
                        end else if (next_key_index == 8) begin
                            key_expansion_rcon_in <= 32'h1b000000;
                        // About to calculate key for round 10.
                        end else begin  // next_key_index == 10;
                            key_expansion_rcon_in <= 32'h36000000;
                        end
                    // Currently key expanding (i.e., results are not  yet ready).
                    end else begin
                        // To avoid continuously starting.
                        key_expansion_start <= 0;
                    end
                end
                // decipher rounds 1-10.
                ROUND: begin
                    // Handles round 1-9.
                    integer i;
                    for (i = 9; i > 0; i = i - 1) begin
                        if (decipher_round_count == i) begin
                            decipher_round_start <= 1;
                            decipher_round_block_in <= current_block;
                            decipher_round_key_in <= keys[i];
                            state <= ROUND_WAIT;
                        end
                    end
                    
                    if (decipher_round_count == 0) begin
                        // Start the chain reaction for round 10, which uses `sub_bytes`,
                        // `shift_row`, and and `add_round_key` (with key expansion).
                        shift_rows_start <= 1;
                        shift_rows_block_in <= current_block;

                        // Move to `OUTPUT`.
                        if (add_round_key_complete) begin
                            // Output the result.
                            result_out <= add_round_key_result;
                            valid_out <= 1;

                            state <= OUTPUT;
                        end
                    end
                end
                ROUND_WAIT: begin
                    // Don't want to continuously be starting.
                    decipher_round_start <= 0;

                    // Once finished with a round, proceed to the next round.
                    if (decipher_round_complete) begin
                        // Update the block and key.
                        current_block <= decipher_round_block_out;
                        current_key <= decipher_round_key_out;

                        // Move to the next round.
                        decipher_round_count <= decipher_round_count - 1;
                        state <= ROUND;
                    end
                end
                // Only stay in `OUTPUT` state for one cycle, then reset.
                OUTPUT: begin
                    valid_out <= 0;
                    state <= WAIT_FOR_START;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
