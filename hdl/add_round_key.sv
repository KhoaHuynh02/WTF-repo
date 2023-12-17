`timescale 1ns / 1ps
`default_nettype none

// Applies `round_key_in` to `block_in` according to the AES transformation
// "add round key".
//
// - Parameters:
//   - clk_in: The clock.
//   - rst_in: Resets the module.
//   - start: Boolean that represents when a new block has been passed in
//     (i.e., when to start the "add round key" transformation). True/1 when
//     a new block has been passed in.
//   - round_key_in: The round key to use.
//   - block_in: The block to apply `round_key_in` to.
// - Results:
//   - result_out: Where the XOR/add round key result is stored.
//   - valid_out: 1 when there's a valid `result_out`.
module add_round_key(
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire start,  // Indicates a new valid block has been passed in.
    input wire [127:0] round_key_in,  // The key.
    input wire [127:0] block_in,  // The new block whose bytes should have the key applied/XORed.
    output logic [127:0] result_out,  // The block with the XORed blocks.
    output logic valid_out  // Goes high for one cycle to indicate that `result_out` is ready.
);
    // Saves the provided `block_in`.
    logic [15:0][7:0] saved_block_in;

    // Saves the passed in key (`round_key_in`).
    logic [15:0][7:0] saved_round_key;

    // The three possible states of the FSM.
    //
    // - WAIT_FOR_START: Resting state; waiting for input.
    // - APPLY_KEY: Actively XORing the current byte.
    // - OUTPUT: Keeps `valid_out` true for one cycle; only 
    //   remains in this state for one cycle.
    typedef enum {WAIT_FOR_START, APPLY_KEY, OUTPUT} add_round_key_state;
    
    // The current state of the FSM.
    add_round_key_state state = WAIT_FOR_START;

    // The index of the bytes to XOR with this cycle.
    //
    // We'll actually be using the bytes at `byte_index` and
    // `byte_index + 1`, since we XOR two at a time, just
    // for the sake of speed.
    logic [4:0] byte_index = 0;
    
    // The lower of the two bytes (from the block) that we're going to XOR with
    // the corresponding byte from the provided key.
    logic [7:0] lower_block_byte;
    assign lower_block_byte = saved_block_in[byte_index];

    // The corresponding byte from the provided key to XOR with
    // `lower_block_byte`.
    logic [7:0] lower_key_byte;
    assign lower_key_byte = saved_round_key[byte_index];

    // The upper of the two bytes (from the block) that we're going to XOR with
    // the corresponding byte from the provided key.
    logic [7:0] upper_block_byte;
    assign upper_block_byte = saved_block_in[byte_index + 1];

    // The corresponding byte from the provided key to XOR with
    // `upper_block_byte`.
    logic [7:0] upper_key_byte;
    assign upper_key_byte = saved_round_key[byte_index + 1];

    // The result is saved here while being computed, then
    // placed in `result_out` once complete.
    logic [15:0][7:0] result_out_internal;

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            byte_index <= 0;
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
                        // Save the inputs.
                        saved_round_key <= round_key_in;
                        saved_block_in <= block_in;

                        byte_index <= 0;
                        result_out <= 128'b0;
                        state <= APPLY_KEY;
                    end
                end
                // Sub in the new byte value.
                APPLY_KEY: begin
                    // XOR the two grabbed bytes.
                    if (byte_index < 16) begin
                        result_out_internal[byte_index] = lower_block_byte ^ lower_key_byte;
                        result_out_internal[byte_index + 1] = upper_block_byte ^ upper_key_byte;
                        byte_index <= byte_index + 2;
                    // All bytes have had the key applied, so proceed to 
                    // output the result.
                    end else begin
                        // Published the results to `result_out`.
                        result_out <= result_out_internal;

                        // Move to the output state.
                        valid_out <= 1;
                        state <= OUTPUT;
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
