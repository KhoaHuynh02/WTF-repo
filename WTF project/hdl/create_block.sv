`timescale 1ns / 1ps
`default_nettype none

// Mixes the columns (i.e., matrix multiplication) of `block_in` according to the AES
//  transformation "mix columns".
//
// - Parameters:
//   - clk_in: The clock.
//   - rst_in: Resets the module.
//   - add_new: Boolean that represents when a new 8-block (i.e., a group of 8 bits)
//     has been passed in. True/1 when a new 8-block has been passed in.
//   - block_in_8: The block to add to the growing (or new) 128-block.
// - Results:
//   - result_out: Where the multiplied result is stored.
//   - valid_out: 1 when there's a valid `result_out`.
module create_block(
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire add_new,  // Indicates a new valid block has been passed in.
    input wire [7:0] block_in_8,  // The new block whose columns should be mixed.
    output logic [15:0][7:0] result_out,  // The block with the mixed columns.
    output logic valid_out  // Goes high for one cycle to indicate that `result_out` is read.
);

    // The three possible states of the FSM.
    //
    // - WAIT_FOR_ADD: Resting state; waiting for input.
    // - MIX_COLS: Actively shifting rows/bytes.
    // - OUTPUT: Keeps `valid_out` true for one cycle; only
    //   remains in this state for one cycle.
    typedef enum {ADD_BLOCK_8, OUTPUT} add_round_key_state;

    // The current state of the FSM.
    add_round_key_state state = ADD_BLOCK_8;

    // Where the next `block_in_8` should be placed (i.e., the next byte to be filled).
    logic [5:0] index = 0;

    logic [15:0][7:0] internal_block;

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            index <= 0;
            result_out <= 128'b0;
            state <= ADD_BLOCK_8;
        end else begin
            case (state)
                ADD_BLOCK_8: begin
                    // Block complete, so output it.
                    if (index == 16) begin
                        result_out <= internal_block;
                        valid_out <= 1;
                        state <= OUTPUT;
                    // Block not yet complete, so continue building.
                    end else if (add_new) begin
                        internal_block[index] <= block_in_8;

                        index <= index + 1;
                    end
                end
                OUTPUT: begin
                    index <= 0;
                    valid_out <= 0;
                    state <= ADD_BLOCK_8;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
