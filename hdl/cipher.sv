`timescale 1ns / 1ps
`default_nettype none

//
//
// - Parameters:
//   -
// - Results:
//   -
module cipher(
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire start,  // Indicates a new valid block has been passed in.
    input wire [127:0] block_in,  // The new block to encrypt.
    input wire [127:0] key_in,  // The key to use for cipher.
    output logic [127:0] result_out,  // The block with the shifted rows.
    output logic valid_out  // Goes high for one cycle to indicate that `result_out` is read.
);

    // The three possible states of the FSM.
    //
    // - WAIT_FOR_START: Resting state; waiting for input.
    // - SHIFT_ROWS: Actively shifting rows/bytes.
    // - OUTPUT: Keeps `valid_out` true for one cycle; only
    //   remains in this state for one cycle.
    typedef enum {WAIT_FOR_START, ROUND, ROUND_WAIT, OUTPUT} cipher_state;

    // The current state of the FSM.
    cipher_state state = WAIT_FOR_START;

    // The current cipher round.
    logic [3:0] cipher_round_count = 0;

    // The current block, which may change over time. 
    logic [127:0] current_block;

    // The key, which will change over time.
    logic [127:0] current_key;

    // The result is saved here while being computed, then
    // placed in `result_out` once complete.
    logic [127:0] saved_output;

    // Sub bytes module.
    logic sub_bytes_start;
    logic [127:0] sub_bytes_block_in;
    logic [127:0] sub_bytes_result;
    logic sub_bytes_complete;
    sub_bytes sub_bytes_inst(
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .new_block_in(sub_bytes_start),  // Indicates a new valid block has been passed in.
        .block_in(sub_bytes_block_in),  // The new block whose bytes should be substituted.
        .subbed_block_out(sub_bytes_result),  // The block with the substituted blocks.
        .valid_out(sub_bytes_complete)  // Goes high for one cycle to indicate that `subbed_block_out` is complete.
    );

    // Shift rows module.
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
        .rcon_in(32'h36000000),  // The Rcon for round 10.
        .expanded_key_out(key_expansion_result),
        .valid_out(key_expansion_complete)
    );

    // Add round key module.
    logic [127:0] add_round_key_result;
    logic [127:0] add_round_key_key_in;
    logic add_round_key_complete;
    add_round_key add_round_key_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .start(shift_rows_complete),  // Indicates a new valid block has been passed in.
        .round_key_in(add_round_key_key_in),  // The key.
        .block_in(shift_rows_result),  // The new block whose bytes should have the key applied/XORed.
        .result_out(add_round_key_result),  // The block with the XORed blocks.
        .valid_out(add_round_key_complete)  // Goes high for one cycle to indicate that `result_out` is ready.
    );

    // Cipher round module.
    logic cipher_round_start;
    logic [127:0] cipher_round_block_in;
    logic [127:0] cipher_round_key_in;
    logic [31:0] cipher_round_rcon_in;
    logic [127:0] cipher_round_block_out;
    logic [127:0] cipher_round_key_out;
    logic cipher_round_complete;
    cipher_round cipher_round_inst(
        // Controls.
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .start(cipher_round_start),

        // Inputs.
        .block_in(cipher_round_block_in),  // Indicates a new valid block has been passed in.
        .key_in(cipher_round_key_in),  // The new block whose bytes should be substituted.
        .rcon_in(cipher_round_rcon_in),

        // Outputs.
        .block_out(cipher_round_block_out),  // The block with the substituted blocks.
        .key_out(cipher_round_key_out),
        .block_complete(cipher_round_complete)  // Goes high for one cycle to indicate that `subbed_block_out` is complete.
    );

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            cipher_round_count <= 0;
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
                        // Initial round.
                        current_block <= block_in ^ key_in;

                        // Save key.
                        current_key <= key_in;

                        result_out <= 128'b0;

                        // Start round 1.
                        cipher_round_count <= 1;
                        state <= ROUND;
                    end
                end
                // Cipher rounds 1-10.
                ROUND: begin
                    // Handles round 1-9.
                    if (cipher_round_count < 9) begin
                        cipher_round_start <= 1;
                        cipher_round_block_in <= current_block;
                        cipher_round_key_in <= current_key;
                        cipher_round_rcon_in <= {8'h01 << (cipher_round_count - 1), 24'h000000};
                        state <= ROUND_WAIT;
                    // Round 9 (has to be handled specially, as the rcon does
                    // not match the previous pattern).
                    end else if (cipher_round_count == 9) begin
                        cipher_round_start <= 1;
                        cipher_round_block_in <= current_block;
                        cipher_round_key_in <= current_key;
                        cipher_round_rcon_in <= 32'h1b000000; // Special case.
                        state <= ROUND_WAIT;
                    // Round 10.
                    end else if (cipher_round_count == 10) begin
                        // Expand the key for use in round 10.
                        key_expansion_start <= 1;
                        key_expansion_key_in <= current_key;

                        // Start the chain reaction for round 10, which uses `sub_bytes`,
                        // `shift_row`, and and `add_round_key` (with key expansion).
                        sub_bytes_start <= 1;
                        sub_bytes_block_in <= current_block;

                        // Move to, and wait in, round 11.
                        cipher_round_count <= cipher_round_count + 1;
    
                    // There is no real round 11, but this just gives us time to
                    // let everything propagate, then save the results.
                    end else if (cipher_round_count == 11) begin
                        // Avoid continuously starting these modules.
                        sub_bytes_start <= 0;
                        key_expansion_start <= 0;

                        // Find the final key.
                        if (key_expansion_complete) begin
                            current_key <= key_expansion_result;
                        end

                        // NOTE: The key expansion must finish before this!!!
                        if (shift_rows_complete) begin
                            result_out <= shift_rows_result ^ current_key;
                            valid_out <= 1;
                            state <= OUTPUT;
                        end
                    end
                end
                ROUND_WAIT: begin
                    // Don't want to continuously be starting.
                    cipher_round_start <= 0;

                    // Once finished with a round, proceed to the next round.
                    if (cipher_round_complete) begin
                        // Update the block and key.
                        current_block <= cipher_round_block_out;
                        current_key <= cipher_round_key_out;

                        // Move to the next round.
                        cipher_round_count <= cipher_round_count + 1;
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
