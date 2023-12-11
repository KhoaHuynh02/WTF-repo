`timescale 1ns / 1ps
`default_nettype none

module fir_tb();
    localparam WIDTH = 16;

    logic clk_100mhz;
    logic rst_in;
    localparam COUNT_PERIOD = 32;
    
    logic old_clk;  // Prior clk val
    logic curr_clk;  // New clk val
    logic clk_3mhz; // A single cycle valid at 3 MHz
    assign clk_3mhz = curr_clk && ~old_clk; // a clock at 3.072 MHz

    logic [5:0] m_clock_counter = 0; //used for counting for mic clock generation
    //generate clock signal for microphone
    always_ff @(posedge clk_100mhz)begin
        curr_clk <= m_clock_counter < COUNT_PERIOD/2;
        m_clock_counter <= (m_clock_counter==COUNT_PERIOD-1)?0:m_clock_counter+1;
        old_clk <= curr_clk;
    end

    logic signed [WIDTH-1:0] data_in;
    // sine.sv
    logic signed [8:0] amp_out;

    logic signed [7:0] fast_sine;
    sine_generator#(
    ) sine_gen(
        .clk_in(clk_100mhz),
        .rst_in(rst_in),
        .step_in(clk_100mhz),
        .amp_out(fast_sine)
    );

    logic signed [7:0] slow_sine;
    sine_generator #(
      .RIGHTSHIFT(14)
    )
    sine_gen_low_freq(
        .clk_in(clk_100mhz),
        .rst_in(rst_in),
        .step_in(clk_100mhz),
        .amp_out(slow_sine)
    );

    // logic signed [7:0] ok_slow_sine;
    // sine_generator #(
    //   .RIGHTSHIFT(10)
    // )
    // sine_gen_ok_low_freq(
    //     .clk_in(clk_100mhz),
    //     .rst_in(rst_in),
    //     .step_in(clk_100mhz),
    //     .amp_out(ok_slow_sine)
    // );

    assign amp_out = slow_sine + fast_sine;

    logic signed [7:0] level_in;
    assign level_in = amp_out[8:1];

    logic pdm_out;
    pdm pdm_module
            ( .clk_in(clk_100mhz),
                .rst_in(rst_in),
                .data_ready(1'b1),
                .level_in(level_in),
                .tick_in(clk_3mhz),
                .pdm_out(pdm_out)
            );

    assign data_in = { {4{pdm_out}}, 4'b0};
    
    // logic first_fad_valid_out;
    // logic signed [15:0] first_fad_data_out;

    // logic first_dec_valid_out;
    // logic signed [15:0] first_dec_data_out;

    // decimate #(.WIDTH(16))
    // dec_one(
    //   .clk(clk),
    //   .rst(rst),
    //   .valid_in(clk_3mhz),
    //   .data_in(data_in),
    //   .valid_out(first_dec_valid_out), 
    //   .data_out(first_dec_data_out) 
    // );
    // fir_and_decimate fad_16bits
    // (
    //     .clk(clk_100mhz),
    //     .rst(rst_in),
    //     .single_valid_in(clk_3mhz),
    //     .data_in(data_in),
    //     .fad_valid_out(first_fad_valid_out),
    //     .fad_data_out(first_fad_data_out)
    // );

    // logic second_fad_valid_out;
    // logic signed [15:0] second_fad_data_out;
    
    // logic second_valid_out;
    // logic signed [15:0] second_fad_data_out;

    // decimate #(.WIDTH(16))
    // dec_two(
    //   .clk(clk),
    //   .rst(rst),
    //   .valid_in(first_dec_valid_out),
    //   .data_in(first_dec_data_out),
    //   .valid_out(first_fad_valid_out), 
    //   .data_out(first_fad_data_out) 
    // );

    // fir_and_decimate second_fad_16bits
    // (
    //     .clk(clk_100mhz),
    //     .rst(rst_in),
    //     .single_valid_in(first_fad_valid_out),
    //     .data_in(first_fad_data_out),
    //     .fad_valid_out(second_fad_valid_out),
    //     .fad_data_out(second_fad_data_out)
    // );

    // logic third_fad_valid_out;
    // logic signed [15:0] third_fad_data_out;

    // fir_and_decimate third_fad_16bits
    // (
    //     .clk(clk_100mhz),
    //     .rst(rst_in),
    //     .single_valid_in(second_fad_valid_out),
    //     .data_in(second_fad_data_out),
    //     .fad_valid_out(third_fad_valid_out),
    //     .fad_data_out(third_fad_data_out)
    // );




    logic signed [7:0] first_stage_8bits_data_in;
    assign first_stage_8bits_data_in = data_in;
    logic first_stage_8bits_valid_out;
    logic signed [7:0] first_stage_8bits_data_out;

    fir_and_decimate_8bits uut
    (
        .clk(clk_100mhz),
        .rst(rst_in),
        .single_valid_in(clk_3mhz),
        .data_in(first_stage_8bits_data_in),
        .fad_valid_out(first_stage_8bits_valid_out),
        .fad_data_out(first_stage_8bits_data_out)
    );
    logic signed [7:0] scaled_8bits;
    assign scaled_8bits = first_stage_8bits_data_out;

    logic second_stage_8bits_valid_out;
    logic signed [7:0] second_stage_8bits_data_out;

    fir_and_decimate_8bits second_stage_fir_decimate
    (
        .clk(clk_100mhz),
        .rst(rst_in),
        .single_valid_in(first_stage_8bits_valid_out),
        .data_in(first_stage_8bits_data_out),
        .fad_valid_out(second_stage_8bits_valid_out),
        .fad_data_out(second_stage_8bits_data_out)
    );

    logic third_stage_8bits_valid_out;
    logic signed [7:0] third_stage_8bits_data_out;

    // fir_and_decimate_8bits third_stage_fir_decimate
    // (
    //     .clk(clk_100mhz),
    //     .rst(rst_in),
    //     .single_valid_in(second_stage_8bits_valid_out),
    //     .data_in(second_stage_8bits_data_out),
    //     .fad_valid_out(third_stage_8bits_valid_out),
    //     .fad_data_out(third_stage_8bits_data_out)
    // );

    decimate #(.WIDTH(8))
    third_decimate(
      .clk(clk_100mhz),
      .rst(rst_in),
      .valid_in(second_stage_8bits_valid_out),
      .data_in(second_stage_8bits_data_out),
      .valid_out(third_stage_8bits_valid_out), 
      .data_out(third_stage_8bits_data_out)
    );


    logic fourth_stage_8bits_valid_out;
    logic signed [7:0] fourth_stage_8bits_data_out;

    fir_and_decimate_8bits fourth_stage_fir_decimate
    (
        .clk(clk_100mhz),
        .rst(rst_in),
        .single_valid_in(third_stage_8bits_valid_out),
        .data_in(third_stage_8bits_data_out),
        .fad_valid_out(fourth_stage_8bits_valid_out),
        .fad_data_out(fourth_stage_8bits_data_out)
    );
    // decimate #(.WIDTH(8))
    // fourth_decimate(
    //   .clk(clk_100mhz),
    //   .rst(rst_in),
    //   .valid_in(third_stage_8bits_valid_out),
    //   .data_in(third_stage_8bits_data_out),
    //   .valid_out(fourth_stage_8bits_valid_out), 
    //   .data_out(fourth_stage_8bits_data_out)
    // );

    logic final_pdm_out;
    pdm pdm_module_final
            (   .clk_in(clk_100mhz),
                .rst_in(rst_in),
                .data_ready(fourth_stage_8bits_valid_out),
                .level_in(fourth_stage_8bits_data_out),
                .tick_in(clk_3mhz),
                .pdm_out(final_pdm_out)
            );
    
    

    /*
     * 100Mhz (10ns) clock 
     */
    always begin
        #5;
        clk_100mhz = !clk_100mhz;
    end

    // logic square_3mhz;
    // always begin
    //     #1000;
    //     square_3mhz = !square_3mhz;
    // end

    




  //initial block...this is our test simulation
  initial begin
    $dumpfile("fir_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,fir_tb);
    $display("Starting Sim"); //print nice message at start
    clk_100mhz = 0;
    rst_in = 0;
    // square_3mhz = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    // data_in = LOW;
    for (int i = 0; i<50; i=i+1)begin
        for (int j = 0; j<128; j=j+1)begin
            // data_in = (data_in == LOW) ? HIGH : LOW;
            #200;
        end 
        // rst_in = 0;
    end
    
    //
    $display("Simulation finished");
    $finish;
  end
    
endmodule

`default_nettype wire