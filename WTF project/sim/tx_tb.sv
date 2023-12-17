`timescale 1ns / 1ps
`default_nettype none

module tx_tb();
    logic clk_in;
    logic rst_in;
    logic valid_in;
    logic slow_clk;
    logic [WIDTH-1:0] audio_in;
    logic out;
    logic busy;

    int dur;
    logic bit_to_send;

    parameter SBD = 1000;  // Sync burst duration.
    parameter SSD = 1000;  // Sync silence duration.
    parameter BBD = 500;  // Bit burst duration.
    parameter BSD0 = 250;  // Bit silence duration (for 0).
    parameter BSD1 = 500;  // Bit silence duration (for 1).
    parameter WIDTH = 128; // The bit depth of the output

    tx
        #(
            .SBD(SBD),
            .SSD(SSD),
            .BBD(BBD),
            .BSD0(BSD0),
            .BSD1(BSD1),
            .WIDTH(WIDTH)
        ) uut 
        (
            .clk_in(clk_in),
            .rst_in(rst_in),
            .valid_in(valid_in),
            .audio_in(audio_in),
            .out(out),
            .busy(busy)
        );

    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    always begin
        #1333333;
        valid_in = 1;
        #10;
        valid_in = 0;
    end

    always begin
        #83333
        slow_clk = 1;
        #10;
        slow_clk = 0;
    end

    initial begin
        $dumpfile("tx.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,tx_tb);
        $display("Starting Sim"); //print nice message at start
        clk_in = 0;
        rst_in = 0;
        #10;
        rst_in = 1;
        #10;
        rst_in = 0;
        audio_in = 'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
        #10000000;
        audio_in = 'h00;
        #20000000;
        $display("Simulation finished");
        $finish;
    end
endmodule

`default_nettype wire