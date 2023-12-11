`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level(
  input wire clk_100mhz,
  input wire [15:0] sw, //all 16 input slide switches
  input wire [3:0] btn, //all four momentary button switches
  output logic [15:0] led, //16 green output LEDs (located right above switches)
  output logic [2:0] rgb0, //rgb led
  output logic [2:0] rgb1, //rgb led
  output logic spkl, spkr, //speaker outputs
  output logic mic_clk, //microphone clock
  input wire  mic_data //microphone data
  );
  assign led = sw; //for debugging
  //shut up those rgb LEDs (active high):
  assign rgb1= 0;
  assign rgb0 = 0;

  logic sys_rst;
  assign sys_rst = btn[0];

  logic clk_m;
  audio_clk_wiz macw (.clk_in(clk_100mhz), .clk_out(clk_m)); //98.3MHz
  // we make 98.3 MHz since that number is cleanly divisible by
  // 32 to give us 3.072 MHz.  3.072 MHz is nice because it is cleanly divisible
  // by nice powers of 2 to give us reasonable audio sample rates. For example,
  // a decimation by a factor of 64 could give us 6 bit 48 kHz audio
  // a decimation by a factor of 256 gives us 8 bit 12 kHz audio
  //we do the latter in this lab.


  // logic record; //signal used to trigger recording
  // //definitely want this debounced:
  // debouncer rec_deb(  .clk_in(clk_m),
  //                     .rst_in(sys_rst),
  //                     .dirty_in(btn[1]),
  //                     .clean_out(record));

  //logic for controlling PDM associated modules:
  // logic [8:0] m_clock_counter; //used for counting for mic clock generation
  // logic audio_sample_valid;//single-cycle enable for samples at ~12 kHz (approx)
  // logic signed [7:0] mic_audio; //audio from microphone 8 bit unsigned at 12 kHz
  // logic[7:0] audio_data; //raw scaled audio data

  //logic for interfacing with the microphone and generating 3.072 MHz signals
  // logic [7:0] pdm_tally;
  // logic [8:0] pdm_counter;

  localparam PDM_COUNT_PERIOD = 32; //
  // localparam NUM_PDM_SAMPLES = 8; // value to use to tally the mic data to produce 8 bits samples

  logic old_mic_clk; //prior mic clock for edge detection
  // logic sampled_mic_data; //one bit grabbed/held values of mic
  
  logic pdm_signal_valid; //single-cycle signal at 3.072 MHz indicating pdm steps
  assign pdm_signal_valid = mic_clk && ~old_mic_clk; // a clock at 3.072 MHz



  logic [5:0] m_clock_counter; //used for counting for mic clock generation
  //generate clock signal for microphone
  always_ff @(posedge clk_m)begin
    mic_clk <= m_clock_counter < PDM_COUNT_PERIOD/2;
    m_clock_counter <= (m_clock_counter==PDM_COUNT_PERIOD-1)?0:m_clock_counter+1;
    old_mic_clk <= mic_clk;
  end

  
  //generate 1 bits audio signal (samples at 3.072 MHZ)
  /*
  Next Step: convert this 3 Msps info to 16 bits fixed point number
  */
  logic signed [15:0] fixed_point_in;
  logic signed [7:0] fixed_point_8bits;

  always_ff @(posedge clk_m)begin
    if (pdm_signal_valid) begin
      // "1" = 00000...10000000    "0" = 111111...00000
      // fixed_point_in <= (mic_data==1'b1)? {8'b1,8'h0} : {8'hFF,8'h0}; 
      fixed_point_in <= {{8{mic_data}},8'h00};
      fixed_point_8bits <= {{4{mic_data}},4'h00};
    end else begin
      // audio_sample_valid <= 0;
      fixed_point_in <= 0;
      fixed_point_8bits <= 0;
    end
  end


  // beginning of 4 stage FIR filter
  logic first_valid_out;
  logic signed [7:0] first_data_out;

  // Stage 1:
  fir_and_decimate_8bits stage_one(
     .clk(clk_m),
     .rst(sys_rst),
     .single_valid_in(pdm_signal_valid), // single cycle 3.072 MHz
     .data_in(fixed_point_8bits),
     .fad_valid_out(first_valid_out), // single cycle 768 KHz
     .fad_data_out(first_data_out)
  );
  

  // // Stage 2:
  // logic second_valid_out;
  // logic signed [7:0] second_data_out;
  // fir_and_decimate_8bits stage_two(
  //   .clk(clk_m),
  //   .rst(sys_rst),
  //   .single_valid_in(first_valid_out), // single cycle 768 KHz
  //   .data_in(first_data_out),
  //   .fad_valid_out(second_valid_out), // single cycle 192 KHz
  //   .fad_data_out(second_data_out)
  // );

  // // Stage 3:
  // logic third_valid_out;
  // logic signed [7:0] third_data_out;

  // fir_and_decimate_8bits stage_three(
  //   .clk(clk_m),
  //   .rst(sys_rst),
  //   .single_valid_in(second_valid_out), // single cycle 192 KHz
  //   .data_in(second_data_out),
  //   .fad_valid_out(third_valid_out), // single cycle 48 KHz
  //   .fad_data_out(third_data_out)
  // );

  // // Stage 4:
  // logic fourth_valid_out;
  // logic signed [7:0] fourth_data_out;

  // fir_and_decimate_8bits stage_four(
  //   .clk(clk_m),
  //   .rst(sys_rst),
  //   .single_valid_in(third_valid_out), // single cycle 48 KHz
  //   .data_in(third_data_out),
  //   .fad_valid_out(fourth_valid_out), // single cycle 12 KHz
  //   .fad_data_out(fourth_data_out)
  // );
  // decimate #(.WIDTH(8))
  //   fourth_decimate(
  //     .clk(clk_m),
  //     .rst(sys_rst),
  //     .valid_in(third_valid_out),
  //     .data_in(third_data_out),
  //     .valid_out(fourth_valid_out), 
  //     .data_out(fourth_data_out)
  //   );
  // 4 stages FIR filter complete

  // logic [7:0] single_audio; //recorder non-echo output
  // logic [7:0] echo_audio; //recorder echo output


  // recorder my_rec(
  //   .clk_in(clk_m), //system clock
  //   .rst_in(sys_rst),//global reset
  //   .record_in(record), //button indicating whether to record or not
  //   .audio_valid_in(audio_sample_valid), //12 kHz audio sample valid signal
  //   .audio_in(mic_audio), //8 bit signed data from microphone
  //   .single_out(single_audio), //played back audio (8 bit signed at 12 kHz)
  //   .echo_out(echo_audio) //played back audio (8 bit signed at 12 kHz)
  // );


  // choose which signal to play:
  // logic [7:0] audio_data_sel;

  // always_comb begin
  //   if (sw[0])beging
  //     // audio_data_sel = tone_750; //signed
  //   end else if (sw[1])begin
  //     // audio_data_sel = tone_440; //signed
  //   end else if (sw[5])begin
  //     // audio_data_sel = mic_audio; //signed
  //   end else if (sw[6])begin
  //     // audio_data_sel = single_audio; //signed
  //   end else if (sw[7])begin
  //     // audio_data_sel = echo_audio; //signed
  //   end else begin
  //     // audio_data_sel = mic_audio; //signed
  //   end
  // end

  logic signed [7:0] vol_in;
  assign vol_in = first_data_out;

  logic data_ready;
  assign data_ready = first_valid_out;
  logic signed [7:0] vol_out; //can be signed or not signed...doesn't really matter
  // logic signed [15:0] vol_out;
  // all this does is convey the output of vol_out to the input of the pdm
  // since it isn't used directly with any sort of math operation its signedness
  // is not as important.
  volume_control vc (.vol_in(sw[15:13]),.signal_in(vol_in), .signal_out(vol_out));


  //PDM:
  logic pdm_out_signal; //an inherently digital signal (0 or 1..no need to make signed)
  //the value is encoded using Pulse Density Modulation
  logic audio_out; //value that drives output channels directly

  pdm my_pdm(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .data_ready(1),
    .level_in(vol_out),
    .tick_in(pdm_signal_valid),
    .pdm_out(pdm_out_signal)
  );

  always_comb begin
    case (sw[4])
      // 2'b00: audio_out = pwm_out_signal;
      // 2'b00: audio_out = audio_out;
      1'b1: audio_out = pdm_out_signal;
      // 2'b10: audio_out = sampled_mic_data;
      1'b0: audio_out = mic_data;
    endcase
  end

  assign spkl = audio_out;
  assign spkr = audio_out;

endmodule // top_level

//Volume Control
module volume_control (
  input wire [2:0] vol_in,
  input wire signed [7:0] signal_in,
  output logic signed [7:0] signal_out);
    logic [2:0] shift;
    assign shift = 3'd7 - vol_in;
    assign signal_out = signal_in>>>shift;
endmodule

`default_nettype wire
