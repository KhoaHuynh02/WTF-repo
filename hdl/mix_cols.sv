`timescale 1ns / 1ps
`default_nettype none

// function automatic [7:0] gf_multiply_by_2(input [7:0] byte_in);
//     begin
//         gf_multiply_by_2 = 
//             {byte_in[6:0], 1'b0} 
//             ^ (8'h1b & {8{byte_in[7]}});
//     end
// endfunction



// // Multiplication by 3 according to GF rules.
// function automatic [7:0] gf_multiply_by_3(input [7:0] byte_in);
//     begin
//         gf_multiply_by_3 = gf_multiply_by_2(byte_in) ^ byte_in;
//     end
// endfunction

// Multiplication by 3, 2, 1, and 1 (according to GF rules), all XORed together.
function automatic [7:0] mix_single_col(
    input [7:0] by_3,
    input [7:0] by_2,
    input [7:0] by_1_0,
    input [7:0] by_1_1
);
    // Function.
    begin
        mix_single_col = 
            gf_multiply_by_3(by_3)  // GF multiplication by 3.
            ^ gf_multiply_by_2(by_2)  // GF multiplication by 2.
            ^ by_1_0  // GF multiplication by 1.
            ^ by_1_1;  // GF multiplication by 1.
    end
endfunction


// Mixes the columns (i.e., matrix multiplication) of `block_in` according to the AES
//  transformation "mix columns".
//
// - Parameters:
//   - clk_in: The clock.
//   - rst_in: Resets the module.
//   - start: Boolean that represents when a new block has been passed in
//     (i.e., when to start the "mix columns" transformation). True/1 when
//     a new block has been passed in.
//   - block_in: The block to multiply.
// - Results:
//   - result_out: Where the multiplied result is stored.
//   - valid_out: 1 when there's a valid `result_out`.
module mix_cols(
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire start,  // Indicates a new valid block has been passed in.
    input wire [127:0] block_in,  // The new block whose columns should be mixed.
    output logic [127:0] result_out,  // The block with the mixed columns.
    output logic valid_out  // Goes high for one cycle to indicate that `result_out` is read.
);

    // The three possible states of the FSM.
    //
    // - WAIT_FOR_START: Resting state; waiting for input.
    // - MIX_COLS: Actively shifting rows/bytes.
    // - OUTPUT: Keeps `valid_out` true for one cycle; only
    //   remains in this state for one cycle.
    typedef enum {WAIT_FOR_START, MIX_COLS, OUTPUT} mix_cols_state;

    // The current state of the FSM.
    mix_cols_state state = WAIT_FOR_START;

    // The col of `block_in` to multiply/add this cycle.
    logic [2:0] col = 0;

    // Where we save `block_in`, so `block_in` doesn't have to held constant.
    logic [3:0][3:0][7:0] saved_block_in;

    // The result is saved here while being computed, then
    // placed in `result_out` once complete.
    logic [3:0][3:0][7:0] saved_output;

    always_ff @(posedge clk_in) begin
        // Reset everything.
        if (rst_in) begin
            col = 0;
            result_out <= 128'b0;
            state <= WAIT_FOR_START;
            valid_out <= 0;
        end else begin
            case (state)
                // Resting state; waiting for input.
                WAIT_FOR_START: begin
                    valid_out <= 0;
                    // New input received; start mixing columns.
                    if (start) begin
                        // Save the input.
                        saved_block_in <= block_in;

                        col <= 0;
                        result_out <= 128'b0;
                        state <= MIX_COLS;
                    end
                end
                // Multiply and add row of `block_in` per cycle (0th row isn't shifted).
                MIX_COLS: begin
                    // Mixes each column, chosing based upon `col`.
                    logic [7:0] row_0, row_1, row_2, row_3, temp;
                    row_0 = saved_block_in[0][col];
                    row_1 = saved_block_in[1][col];
                    row_2 = saved_block_in[2][col];
                    row_3 = saved_block_in[3][col];

                    // Place the result of mixing column `col` of `block_in
                    // in (0, col) of `saved_output`. A "matrix multiplication"
                    // of the first row of the precomputed table by the first
                    // column of `block_in`. This is all specified in AES protocol.
                    saved_output[0][col] <= mix_single_col(row_3, row_0, row_1, row_2);
                    
                    saved_output[1][col] <= mix_single_col(row_0, row_1, row_2, row_3);
                    
                    saved_output[2][col] <= mix_single_col(row_1, row_2, row_3, row_0);
                    
                    saved_output[3][col] <= mix_single_col(row_2, row_3, row_0, row_1);

                    // Shift state to `OUTPUT`, since all calculations are complete.
                    if (col == 4) begin
                        // Put the result (in `saved_output`) to `result_out`.
                        result_out <= saved_output;
                        valid_out <= 1;
                        state <= OUTPUT;
                    end

                    // Move to the next column.
                    col <= col + 1;
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
