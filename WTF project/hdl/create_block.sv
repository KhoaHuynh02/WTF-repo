`timescale 1ns / 1ps
`default_nettype none

// Mixes the columns (i.e., matrix multiplication) of `block_in` according to the AES
//  transformation "mix columns".
//
// - Parameters:
//   - clk_in: The clock.
//   - rst_in: Resets the module.
//   - start: Boolean that represents when a new 8-block (i.e., a group of 8 bits)
//     has been passed in. True/1 when a new 8-block has been passed in.
//   - block_in_8: The block to add to the growing (or new) 128-block.
// - Results:
//   - result_out: Where the multiplied result is stored.
//   - valid_out: 1 when there's a valid `result_out`.
module create_block(
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire start,  // Indicates a new valid block has been passed in.
    input wire [7:0] block_in_8,  // The new block whose columns should be mixed.
    output logic [15:0][7:0] result_out,  // The block with the mixed columns.
    output logic valid_out  // Goes high for one cycle to indicate that `result_out` is read.
);

    // The three possible states of the FSM.
    //
    // - WAIT_FOR_START: Resting state; waiting for input.
    // - MIX_COLS: Actively shifting rows/bytes.
    // - OUTPUT: Keeps `valid_out` true for one cycle; only
    //   remains in this state for one cycle.
    typedef enum {WAIT_FOR_START, CREATE_BLOCK, OUTPUT} add_round_key_state;

    // The current state of the FSM.
    add_round_key_state state = WAIT_FOR_START;

    // Where the next `block_in_8` should be placed (i.e., the next byte to be filled).
    logic [4:0] next_index = 0;

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            next_index <= 0;
            result_out <= 128'b0;
        end else begin
            case (state)
                // Resting state; waiting for input.
                WAIT_FOR_START: begin
                    // New input received; start mixing columns.
                    if (start) begin
                        next_index <= 0;
                        result_out <= 128'b0;
                        state <= CREATE_BLOCK;
                    end
                end
                // Multiply and add row of `block_in` per cycle (0th row isn't shifted).
                CREATE_BLOCK: begin
                    // Places the 8-block in the proper location in the 128-block.
                    result_out[next_index] <= block_in_8;

                    // Handles FSM state changes and incrementing `next_index`.
                    if (next_index == 15) begin
                        // Shift state to `OUTPUT`, since all calculations are complete.
                        valid_out <= 1;
                        state <= OUTPUT;
                    // Increment index.
                    end else begin
                        next_index <= next_index + 1;
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
