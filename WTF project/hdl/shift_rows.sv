`timescale 1ns / 1ps
`default_nettype none

// Applies shifts to each row of `block_in` according to the AES transformation
// "shift rows".
//
// - Parameters:
//   - clk_in: The clock.
//   - rst_in: Resets the module.
//   - start: Boolean that represents when a new block has been passed in
//     (i.e., when to start the "shift rows" transformation). True/1 when
//     a new block has been passed in.
//   - block_in: The block whose rows will be shifted.
// - Results:
//   - result_out: Where the row-shifted result is stored.
//   - valid_out: 1 when there's a valid `result_out`.
module shift_rows(
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire start,  // Indicates a new valid block has been passed in.
    input wire [127:0] block_in,  // The new block whose rows should be shifted.
    output logic [127:0] result_out,  // The block with the shifted rows.
    output logic valid_out  // Goes high for one cycle to indicate that `result_out` is read.
);

    // The three possible states of the FSM.
    //
    // - WAIT_FOR_START: Resting state; waiting for input.
    // - SHIFT_ROWS: Actively shifting rows/bytes.
    // - OUTPUT: Keeps `valid_out` true for one cycle; only
    //   remains in this state for one cycle.
    typedef enum {WAIT_FOR_START, SHIFT_ROWS, OUTPUT} shift_rows_state;

    // The current state of the FSM.
    shift_rows_state state = WAIT_FOR_START;

    // The row to shift this cycle.
    logic [2:0] row = 0;

    // `block_in` is saved here, just in case it changes.
    logic [3:0][3:0][7:0] saved_block_in;

    // The result is saved here while being computed, then
    // placed in `result_out` once complete.
    logic [3:0][3:0][7:0] saved_output;

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            row <= 0;
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
                        saved_block_in <= block_in;

                        row <= 0;
                        result_out <= 128'b0;
                        state <= SHIFT_ROWS;
                    end
                end
                // Shift one row per cycle (0th row isn't shifted).
                SHIFT_ROWS: begin
                    // Shift row 0 left by 3.
                    if (row == 0) begin
                        saved_output[0] <= {saved_block_in[0][0], saved_block_in[0][3:1]};
                    // Shift row 1 left by 2.
                    end else if (row == 1) begin
                        saved_output[1] <= {saved_block_in[1][1:0], saved_block_in[1][3:2]};
                    // Shift row 2 left by 1.
                    end else if (row == 2) begin
                        saved_output[2] <= {saved_block_in[2][2:0], saved_block_in[2][3]};
                    // Shift row 3 left by 0.
                    end else if (row == 3) begin
                        saved_output[3] <= saved_block_in[3];
                    // Complete, so proceed to output the result.
                    end else begin
                        // Place the result in `result_out`.
                        result_out <= saved_output;

                        valid_out <= 1;
                        state <= OUTPUT;
                    end

                    row <= row + 1;
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
