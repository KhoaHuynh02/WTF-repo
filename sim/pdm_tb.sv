`timescale 1ns / 1ps
`default_nettype none

module pdm_tb();

  logic clk_in;
  logic rst_in;
  logic signed [7:0] level_in;
  logic tick_in;
  logic pdm_out;
  pdm uut
          ( .clk_in(clk_in),
            .rst_in(rst_in),
            .level_in(level_in),
            .tick_in(tick_in),
            .pdm_out(pdm_out)
          );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("pdm_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,pdm_tb);
    $display("Starting Sim"); //print nice message at start
    clk_in = 0;
    rst_in = 0;
    level_in = 0;
    tick_in = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    for (int i = 0; i<128; i=i+1)begin
      level_in = i;
      for (int j = 0; j<30; j=j+1)begin
        tick_in = 1;
        #10;
        tick_in = 0;
        #10;
      end
    end
    for (int i = 127; i>=-128; i=i-1)begin
      level_in = i;
      for (int j = 0; j<30; j=j+1)begin
        tick_in = 1;
        #10;
        tick_in = 0;
        #10;
      end
    end
    for (int i = -128; i<0; i=i+1)begin
      level_in = i;
      for (int j = 0; j<30; j=j+1)begin
        tick_in = 1;
        #10;
        tick_in = 0;
        #10;
      end
    end
    $display("Simulation finished");
    $finish;
  end
endmodule
`default_nettype wire
