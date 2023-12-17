`timescale 1ns / 1ps
`default_nettype none

module decipher(
    input wire clk_in,
    input wire rst_in,
    input wire start,
    input wire [127:0] block_in,
    input wire [127:0] key_in,
    output logic [127:0] deciphered_block,
    output logic decipher_complete
);  
    // - MARK: Key expansion modules and variables.

    logic key_expansion_start;
    logic [127:0] key_expansion_key_in;
    logic [31:0] key_expansion_rcon_in;
    logic [127:0] key_expansion_result;
    logic key_expansion_complete;
    key_expansion key_expansion_inst(
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .new_key_in(key_expansion_start),  // Indicates a new valid word has been passed in.
        .key_in(key_expansion_key_in),
        .rcon_in(key_expansion_rcon_in),
        .expanded_key_out(key_expansion_result),
        .valid_out(key_expansion_complete)
    );

    typedef enum {
        WAIT,
        GENERATE_KEYS,
        DECIPHER_INITIAL,
        ROUNDS,
        ROUND_WAIT,
        DECIPHER_FINAL,
        OUTPUT
    } generate_all_keys_state;

    // The state of the FSM.
    generate_all_keys_state state;

    logic [127:0] keys [10:0];

    // When used, it is the most recent key generation round that has completed.
    logic [3:0] key_completed_round;

    // - MARK: Decipher modules and variables.

    logic decipher_round_start;
    logic [127:0] decipher_round_block_in;
    logic [127:0] decipher_round_key_in;
    logic [127:0] decipher_round_result;
    logic decipher_round_complete;
    decipher_round decipher_round_inst(
        // Controls.
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .start(decipher_round_start),  // Indicates a new valid block has been passed in.

        // Inputs.
        .block_in(decipher_round_block_in),  // The new block to encrypt.
        .key_in(decipher_round_key_in),  // The key to use for AES (with key expansion already applied).

        // Outputs.
        .block_out(decipher_round_result),  // The block with the shifted rows.
        .block_complete(decipher_round_complete)  // Goes high for one cycle to indi
    );

    logic [3:0] decipher_round;

    // The block as it is deciphered.
    logic [127:0] current_block;

    // - MARK: Decipher final round modules and variables.

    logic final_modified_round_start;
    logic [127:0] inv_shift_rows_result;
    logic inv_shift_rows_complete;
    inv_shift_rows inv_shift_rows_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .start(final_modified_round_start),
        .block_in(current_block),
        .result_out(inv_shift_rows_result),
        .valid_out(inv_shift_rows_complete)
    );

    logic [127:0] inv_sub_bytes_result;
    logic inv_sub_bytes_complete;
    inv_sub_bytes inv_sub_bytes_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .new_block_in(inv_shift_rows_complete),
        .block_in(inv_shift_rows_result),
        .inv_subbed_block_out(inv_sub_bytes_result),
        .valid_out(inv_sub_bytes_complete)
    );

    always_ff @(posedge clk_in) begin
        // Reset.
        if (rst_in) begin
            key_expansion_start <= 0;
            decipher_round <= 0;

            state <= WAIT;
        end else begin
            case (state)
                WAIT: begin
                    if (start) begin
                        // Save the passed in block.
                        current_block <= block_in;

                        // Save the first key.
                        keys[0] <= key_in;

                        // Start the key expansion.
                        key_expansion_key_in <= key_in;
                        key_expansion_rcon_in <= 31'h01000000;
                        key_completed_round <= 1;

                        key_expansion_start <= 1;

                        state <= GENERATE_KEYS;
                    end
                end
                GENERATE_KEYS: begin
                    if (key_expansion_complete) begin
                        // Save the computed key.
                        keys[key_completed_round] <= key_expansion_result;

                        if (key_completed_round < 8) begin
                            // Initialize next round of key generation.
                            key_expansion_key_in <= key_expansion_result;
                            key_expansion_rcon_in <= 31'h01000000 << (key_completed_round);
                            key_expansion_start <= 1;

                        // Special cases for rounds 9 and 10, plus finishes
                        // in round 11.
                        end else begin
                            if (key_completed_round == 8) begin
                                // Initialize next round of key generation.
                                key_expansion_key_in <= key_expansion_result;
                                key_expansion_rcon_in <= 31'h1b000000;
                                key_expansion_start <= 1;
                            end else if (key_completed_round == 9) begin
                                // Initialize next round of key generation.
                                key_expansion_key_in <= key_expansion_result;
                                key_expansion_rcon_in <= 31'h36000000;
                                key_expansion_start <= 1;

                            // All keys generated, proceed to deciphering.
                            end else if (key_completed_round == 10) begin
                                // Start the deciphering.
                                state <= DECIPHER_INITIAL;
                            end
                        end

                        // Increment rounds.
                        key_completed_round <= key_completed_round + 1;
                    end else begin
                        key_expansion_start <= 0;
                    end
                end
                DECIPHER_INITIAL: begin
                    // Initial add round key.
                    current_block <= current_block ^ keys[10];
                    
                    // Carry out the nine rounds of deciphering.
                    decipher_round <= 9;
                    state <= ROUNDS;
                end
                ROUNDS: begin
                    // Start the next round.
                    decipher_round_block_in <= current_block;
                    decipher_round_key_in <= keys[decipher_round];
                    decipher_round_start <= 1;

                    // Wait for results before moving to the next round.
                    decipher_round <= decipher_round - 1;
                    state <= ROUND_WAIT;
                end 
                ROUND_WAIT: begin
                    // To avoid continuously starting.
                    decipher_round_start <= 0;

                    if (decipher_round_complete) begin
                        // Update the current block.
                        current_block <= decipher_round_result;

                        // Check if done with all rounds; move to final steps if so.    
                        if (decipher_round == 0) begin
                            // Start the final modified round.
                            final_modified_round_start <= 1;
                            state <= DECIPHER_FINAL;
                        // Continue with the next round if not yet finished.
                        end else begin
                            state <= ROUNDS;
                        end
                    end
                end
                DECIPHER_FINAL: begin
                    // To avoid continously starting.
                    final_modified_round_start <= 0;

                    // If finished, apply the final round key, then output
                    // the result.
                    if (inv_sub_bytes_complete) begin
                        // Final application of the round key.
                        deciphered_block <= inv_sub_bytes_result ^ keys[decipher_round];
                        decipher_complete <= 1;

                        state <= OUTPUT;
                    end
                end
                OUTPUT: begin
                    decipher_complete <= 0;
                    state <= WAIT;
                end
            endcase
        end
    end

endmodule

`default_nettype wire