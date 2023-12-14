`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

// Substitutes the bytes in `block_in` according to the AES transformation
// "inverse sub bytes".
//
// - Parameters:
//   - clk_in: The clock.
//   - rst_in: Resets the module.
//   - new_block_in: Boolean that represents when a new block has been passed in
//     (i.e., when to start the "sub_byte" transformation). True/1 when
//     a new block has been passed in.
//   - block_in: The block whose bytes should be substituted/replaced.
// - Results:
//   - inv_subbed_block_out: The block with the substitued/replaced bytes.
//   - valid_out: 1 when there's a valid `inv_subbed_block_out`.
module inv_sub_bytes(
    input wire clk_in,  // The clock.
    input wire rst_in,  // Reset.
    input wire new_block_in,  // Indicates a new valid block has been passed in.
    input wire [15:0][7:0] block_in,  // The new block whose bytes should be substituted.
    output logic [15:0][7:0] inv_subbed_block_out,  // The block with the substituted blocks.
    output logic valid_out  // Goes high for one cycle to indicate that `inv_subbed_block_out` is complete.
);

    // The three possible states of the FSM.
    //
    // - WAIT_FOR_BLOCK: Resting state; waiting for input.
    // - INIT: Handles the special first case.
    // - SUB: Actively subbing in new byte values.
    // - PAUSE: One extra cycle of delay, given the reponse time of BRAM.
    // - OUTPUT: Keeps `valid_out` true for one cycle; only
    //   remains in this state for one cycle.
    typedef enum {WAIT_FOR_BLOCK, INIT0, INIT, INV_SUB, PAUSE, OUTPUT} sub_bytes_state;

    // The current state of the FSM.
    sub_bytes_state state = WAIT_FOR_BLOCK;

    // A place to save the passed in block (in case the passed in block changes).
    logic [15:0][7:0] saved_block;

    // The result is saved here while being computed, then
    // placed in `result_out` once complete.
    logic [15:0][7:0] inv_subbed_block_internal;

    // The index of the next byte that we are going to replace (and therefore the
    // byte that we should start finding the sub value for now).
    logic [4:0] next_byte_index;

    // The index of the byte to replace this cycle.
    logic [4:0] current_byte_index;
    assign current_byte_index = next_byte_index - 1;

    // The value of the next byte that we're going to replace.
    logic [7:0] next_byte;
    assign next_byte = saved_block[next_byte_index];

    // The address ofx the substitute value for `next_byte`.
    logic [7:0] mem_address;
    assign mem_address = ({4'b0000, next_byte[7:4]} << 4) + next_byte[3:0];

    // The substitute value for `next_byte`.
    logic [7:0] sub_byte;

    // Allows us to stay in the `INIT` state for two cycles, rather than one.
    logic init_paused;

    // logic [31:0] clock_count;
    // initial clock_count = 0;

    // Retrieve the byte substitute.
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),  // Specify RAM data width
        .RAM_DEPTH(256),  // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"  // TODO QUESTION: What's the difference?
        .INIT_FILE(`FPATH(inv_byte_sub_table.mem))  // Specify name/location of RAM initialization file if using one (leave blank if not).
    ) sub_table (
        .addra(mem_address),  // Address bus, width determined from RAM_DEPTH.
        .dina(8'h00),  // RAM input data, width determined from RAM_WIDTH.
        .clka(clk_in),  // Clock.
        .wea(1'b0),  // Write enable.
        .ena(1'b1),  // RAM Enable, for additional power savings, disable port when not in use.
        .rsta(rst_in),  // Output reset (does not affect memory contents).
        .regcea(1'b1),  // Output register enable.
        .douta(sub_byte)  // RAM output data, width determined from RAM_WIDTH.
    );

    always_ff @(posedge clk_in) begin
        // clock_count <= clock_count + 1;
        // Reset everything.
        if (rst_in) begin
            next_byte_index <= 0;
            valid_out <= 0;
            state <= WAIT_FOR_BLOCK;
            inv_subbed_block_out <= 128'b0;
            init_paused <= 0;
        end else begin
            case (state)
                // Resting state; waiting for input.
                WAIT_FOR_BLOCK: begin
                    valid_out <= 0;
                    // New input received; start grabbing the next byte;
                    if (new_block_in) begin
                        // Save the passed in block.
                        saved_block <= block_in;

                        // Ensures we substitute all blocks, starting
                        // with the 0th one.
                        next_byte_index <= 0;

                        inv_subbed_block_internal <= 0;
                        valid_out <= 0;

                        // Allows us to stay in `INIT` for two cycles.
                        init_paused <= 0;
                        state <= INIT;
                    end
                end
                // For handling the first (i.e. 0th) byte.
                INIT: begin
                    // Keeps the state as `INIT` for two cycles.
                    if (~init_paused) begin
                        init_paused <= 1'b1;
                    // Already spent two cycles in `INIT` state, so move on.
                    end else begin
                        state <= INV_SUB;
                        next_byte_index <= next_byte_index + 1;
                    end
                end
                // Pause for one cycle to give the BRAM time to respond.
                PAUSE: begin
                    state <= INV_SUB;
                end
                // Sub in the new byte value.
                INV_SUB: begin
                    // Substitute/replace the current byte.
                    if (current_byte_index < 16) begin
                        inv_subbed_block_internal[current_byte_index] <= sub_byte;
                        state <= PAUSE;
                    // All bytes have been substituted/replaced, so
                    // proceed to output the result.
                    end else begin
                        valid_out <= 1;
                        inv_subbed_block_out <= inv_subbed_block_internal;
                        state <= OUTPUT;
                    end

                    next_byte_index <= next_byte_index + 1;
                end
                // Only stay in `OUTPUT` state for one cycle, then reset.
                OUTPUT: begin
                    valid_out <= 0;
                    next_byte_index <= 0;
                    state <= WAIT_FOR_BLOCK;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
