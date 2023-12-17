`timescale 1ns / 1ps
`default_nettype none

module rx_tb();

  logic clk_in;
  logic rst_in;
  logic signal_in;
  logic [WIDTH-1:0] code_out;
  logic new_code_out;
  logic [2:0] error_out;
  logic [3:0] state_out;

  logic [WIDTH-1:0] message = 'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
  int dur;
  logic bit_to_send;

  parameter SBD = 1000;  // Sync burst duration.
  parameter SSD = 1000;  // Sync silence duration.
  parameter BBD = 500;  // Bit burst duration.
  parameter BSD0 = 250;  // Bit silence duration (for 0).
  parameter BSD1 = 500;  // Bit silence duration (for 1).
  parameter MARGIN = 100;  // The +/- of your signals.
  parameter WIDTH = 128; // The bit depth of the output

  rx
       #(.SBD(SBD),
         .SSD(SSD),
         .BBD(BBD),
         .BSD0(BSD0),
         .BSD1(BSD1),
         .MARGIN(MARGIN),
         .WIDTH(WIDTH)
        ) uut
        ( .clk_in(clk_in),
          .rst_in(rst_in),
          .signal_in(signal_in),
          .code_out(code_out),
          .new_code_out(new_code_out),
          .error_out(error_out),
          .state_out(state_out)
        );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("rx.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,rx_tb);
    $display("Starting Sim"); //print nice message at start
    clk_in = 0;
    rst_in = 0;
    signal_in = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    $display("Sync Portion...");
    signal_in = 1;
    dur = $signed(SBD); //+$random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in= 0;
    dur = $signed(SSD);// + $random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    for (int j=0; j<WIDTH; j = j+1)begin
      signal_in=1;
      dur = $signed(BBD);// +$random(seed)%(MARGIN-1);
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      if (message[WIDTH-1])begin
        dur = $signed(BSD1);// +$random(seed)%(MARGIN-1);
      end else begin
        dur = $signed(BSD0);// +$random(seed)%(MARGIN-1);
      end
      signal_in= 0;
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      message = {message[WIDTH-2:0],1'b0};
    end
    //final dip
    signal_in=1;
    dur = $signed(BBD);// +$random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in = 0;
    $display("Second Message");
    #500;
    message = 'hBA;
    signal_in = 1;
    dur = $signed(SBD);// +$random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in=0;
    dur = $signed(SSD);// + $random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    for (int j=0; j<WIDTH; j = j+1)begin
      signal_in=1;
      dur = $signed(BBD);// +$random(seed)%(MARGIN-1);
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      if (message[WIDTH-1])begin
        dur = $signed(BSD1);// +$random(seed)%(MARGIN-1);
      end else begin
        dur = $signed(BSD0);// +$random(seed)%(MARGIN-1);
      end
      signal_in=0;
      for (int i=0; i < dur; i=i+1)begin
        #10;
      end
      message = {message[WIDTH-2:0],1'b0};
    end
    //final dip
    signal_in=1;
    dur = $signed(BBD);// +$random(seed)%(MARGIN-1);
    for (int i=0; i < dur; i=i+1)begin
      #10;
    end
    signal_in = 0;
    #500;
    $display("Simulation finished");
    $finish;
  end
endmodule
`default_nettype wire