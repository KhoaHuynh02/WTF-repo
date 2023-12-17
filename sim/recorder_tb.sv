`timescale 1ns / 1ps
`default_nettype none

module recorder_tb();

  logic clk_in;
  logic rst_in;
  logic audio_valid_in;
  logic record_in;
  logic [7:0] audio_in, single_out, echo_out;

  recorder my_recorder(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .record_in(record_in),
    .audio_valid_in(audio_valid_in),
    .audio_in(audio_in),
    .single_out(single_out),
    .echo_out(echo_out)
  );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("recorder_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,recorder_tb);
    $display("Starting Sim"); //print nice message at start
    clk_in = 0;
    rst_in = 0;
    audio_valid_in = 0;
    record_in = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    record_in = 1;
    for (int i = 0; i<10000; i=i+1)begin
      audio_in = i;
      audio_valid_in = 1;
      #10;
    end
    record_in = 0;
    for (int i = 0; i<10000; i= i+ 1)begin
      audio_valid_in = 1;
      #10;
      audio_valid_in = 0;
      #60;
    end
    $display("Simulation finished");
    $finish;
  end
endmodule
`default_nettype wire
