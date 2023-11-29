`timescale 1ns / 1ps
`default_nettype none

module fir_tb();
    localparam WIDTH = 16;

    logic clk_100mhz;
    logic rst_in;
    logic clk_3mhz;
    logic clk_slow;
    logic signed [WIDTH-1:0] data_in;
    
    // sine.sv
    logic signed [7:0] amp_out;
    sine_generator sine_gen(
        .clk_in(clk_100mhz),
        .rst_in(rst_in),
        .step_in(clk_3mhz),
        .amp_out(amp_out)
    );
    assign data_in = { {4{amp_out[7]}},amp_out[7:0],{4{amp_out[0]}} };

    logic valid_out;
    logic signed [WIDTH-1:0] fir_out;
    fir_module uut
          ( .clk(clk_100mhz),
            .rst(rst_in),
            .enable(clk_3mhz),
            .data_in(data_in),
            
            .valid_out(valid_out),
            .out(fir_out)
          );

    logic first_dec_in_valid;
    assign first_dec_in_valid = (valid_out && clk_3mhz /* 3MHZ */);

    logic first_stage_valid_out;
    logic signed [15:0] first_stage_out;

    decimate first_decimate(
      .clk(clk_100mhz),
      .rst(rst_in),
      .valid_in(first_dec_in_valid),
      .data_in(fir_out),
      .valid_out(first_stage_valid_out), // should follows frequency of 786KHZ
      .data_out(first_stage_out) // should expect 786KHZ at 16 bit depths
    );


    // logic valid_out2;
    // logic signed [WIDTH-1:0] fir_out2;

    // fir_module uut2
    //       ( .clk(clk_100mhz),
    //         .rst(rst_in),
    //         .enable(valid_out && clk_3mhz),
    //         .data_in(fir_out),
            
    //         .valid_out(valid_out2),
    //         .out(fir_out2)
    //       );
    
    

    /*
     * 100Mhz (10ns) clock 
     */
    always begin
        #5;
        clk_100mhz = !clk_100mhz;
    end

    always begin
        #162;
        clk_3mhz = !clk_3mhz;
    end

    always begin
        #486;
        clk_slow = !clk_slow;
    end

    




  //initial block...this is our test simulation
  initial begin
    $dumpfile("fir_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,fir_tb);
    $display("Starting Sim"); //print nice message at start
    clk_100mhz = 0;
    clk_3mhz = 0;
    clk_slow = 0;
    rst_in = 0;
    // data_in = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    // data_in = LOW;
    for (int i = 0; i<10; i=i+1)begin
        for (int j = 0; j<128; j=j+1)begin
            // data_in = (data_in == LOW) ? HIGH : LOW;
            #160;
        end 
        // rst_in = 0;
    end
    
    //
    $display("Simulation finished");
    $finish;
  end
    
endmodule

`default_nettype wire