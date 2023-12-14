`timescale 1ns / 1ps
`default_nettype none

// Tests the `byte_sub` module.
module create_block_tb;

    logic clk_in;
    logic rst_in;
    logic add_new;
    logic [7:0] block_in_8;
    logic [15:0][7:0] create_block_result;
    logic create_block_complete;
    create_block create_block_inst(
        .clk_in(clk_in),  // The clock.
        .rst_in(rst_in),  // Reset.
        .add_new(add_new),  // Indicates a new valid block has been passed in.
        .block_in_8(block_in_8),  // The new block whose columns should be mixed.
        .result_out(create_block_result),  // The block with the mixed columns.
        .valid_out(create_block_complete)  // Goes high for one cycle to indicate that `result_out` is read.
    );

    always begin
        #5;  // Every 5 ns switch...so period of clock is 10 ns...100 MHz clock.
        clk_in = !clk_in;
    end

    // Initial block...this is our test simulation.
    initial begin
        // MARK: Test 1.

        $dumpfile("create_block_tb.vcd");  // File to store value change dump (vcd).
        $dumpvars(0, create_block_tb);  // Store everything at the current level and below.
        $display("Starting `create_block_tb`");  // Print nice message.
        clk_in = 0;  // Initialize clk (super important).
        rst_in = 0;  // Initialize rst (super important).
        add_new = 0;
        #10  // Wait a little bit of time at beginning/
        rst_in = 1;  // Reset system/
        #10;  // Hold high for a few clock cycles.
        rst_in=0;
        #10;

        // - MARK: Block 1 creation.

        // Block 1.
        #200
        block_in_8 = 8'h01;
        add_new = 1;
        #10
        add_new = 0;

        // Block 2.
        #200
        block_in_8 = 8'h02;
        add_new = 1;
        #10
        add_new = 0;

        // Block 3.
        #200
        block_in_8 = 8'h03;
        add_new = 1;
        #10
        add_new = 0;

        // Block 4.
        #200
        block_in_8 = 8'h04;
        add_new = 1;
        #10
        add_new = 0;

        // Block 5.
        #200
        block_in_8 = 8'h05;
        add_new = 1;
        #10
        add_new = 0;

        // Block 6.
        #200
        block_in_8 = 8'h06;
        add_new = 1;
        #10
        add_new = 0;

        // Block 7.
        #200
        block_in_8 = 8'h07;
        add_new = 1;
        #10
        add_new = 0;

        // Block 8.
        #200
        block_in_8 = 8'h08;
        add_new = 1;
        #10
        add_new = 0;

        // Block 9.
        #200
        block_in_8 = 8'h09;
        add_new = 1;
        #10
        add_new = 0;

        // Block 10.
        #200
        block_in_8 = 8'h10;
        add_new = 1;
        #10
        add_new = 0;

        // Block 11.
        #200
        block_in_8 = 8'h11;
        add_new = 1;
        #10
        add_new = 0;
        
        // Block 12.
        #200
        block_in_8 = 8'h12;
        add_new = 1;
        #10
        add_new = 0;

        // Block 13.
        #200
        block_in_8 = 8'h13;
        add_new = 1;
        #10
        add_new = 0;

        // Block 14.
        #200
        block_in_8 = 8'h14;
        add_new = 1;
        #10
        add_new = 0;

        // Block 15.
        #200
        block_in_8 = 8'h15;
        add_new = 1;
        #10
        add_new = 0;

        // Block 16.
        #200
        block_in_8 = 8'h16;
        add_new = 1;
        #10
        add_new = 0;

        // - MARK: Block 2 creation.

        // Block 1.
        #200
        block_in_8 = 8'h15;
        add_new = 1;
        #10
        add_new = 0;

        // Block 2.
        #200
        block_in_8 = 8'h14;
        add_new = 1;
        #10
        add_new = 0;

        // Block 3.
        #200
        block_in_8 = 8'h13;
        add_new = 1;
        #10
        add_new = 0;

        // Block 4.
        #200
        block_in_8 = 8'h12;
        add_new = 1;
        #10
        add_new = 0;

        // Block 5.
        #200
        block_in_8 = 8'h11;
        add_new = 1;
        #10
        add_new = 0;

        // Block 6.
        #200
        block_in_8 = 8'h10;
        add_new = 1;
        #10
        add_new = 0;

        // Block 7.
        #200
        block_in_8 = 8'h09;
        add_new = 1;
        #10
        add_new = 0;

        // Block 8.
        #200
        block_in_8 = 8'h08;
        add_new = 1;
        #10
        add_new = 0;

        // Block 9.
        #200
        block_in_8 = 8'h07;
        add_new = 1;
        #10
        add_new = 0;

        // Block 10.
        #200
        block_in_8 = 8'h06;
        add_new = 1;
        #10
        add_new = 0;

        // Block 11.
        #200
        block_in_8 = 8'h05;
        add_new = 1;
        #10
        add_new = 0;
        
        // Block 12.
        #200
        block_in_8 = 8'h04;
        add_new = 1;
        #10
        add_new = 0;

        // Block 13.
        #200
        block_in_8 = 8'h03;
        add_new = 1;
        #10
        add_new = 0;

        // Block 14.
        #200
        block_in_8 = 8'h02;
        add_new = 1;
        #10
        add_new = 0;

        // Block 15.
        #200
        block_in_8 = 8'h01;
        add_new = 1;
        #10
        add_new = 0;

        // Block 16.
        #200
        block_in_8 = 8'h00;
        add_new = 1;
        #10
        add_new = 0;

        #1000
        $display("Finishing `create_block_tb`");
        $finish;

    end
endmodule // counter_tb

`default_nettype wire
