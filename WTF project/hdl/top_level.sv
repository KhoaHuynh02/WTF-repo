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

  localparam PDM_COUNT_PERIOD = 32; // want to turn 98Mhz to 24 Mhz
  // localparam NUM_PDM_SAMPLES = 8; // value to use to tally the mic data to produce 8 bits samples

  logic old_mic_clk; //prior mic clock for edge detection
  // logic sampled_mic_data; //one bit grabbed/held values of mic
  
  logic pdm_signal_valid; //single-cycle signal at 3.072 MHz indicating pdm steps
  assign pdm_signal_valid = mic_clk && ~old_mic_clk; // a clock at 3.072 MHz



  logic [2:0] m_clock_counter; //used for counting for mic clock generation
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

  always_ff @(posedge clk_m)begin
    if (pdm_signal_valid) begin
      // "1" = 00000...10000000    "0" = 111111...00000
      fixed_point_in <= (mic_data==1'b1)? {8'b1,8'h0} : {8'hFF,8'h0}; 
    end else begin
      // audio_sample_valid <= 0;
      fixed_point_in <= 0;
    end
  end


  // beginning of 4 stage FIR filter

  // Stage 1:
  logic first_fir_valid_out;
  logic signed [15:0] first_fir_out;

  fir_module first_fir(
    .clk(clk_m),
    .rst(sys_rst),
    .enable(pdm_signal_valid),
    .data_in(fixed_point_in),
    .valid_out(first_fir_valid_out),
    .out(first_fir_out)
  );

  logic first_dec_in_valid;
  assign first_dec_in_valid = (first_fir_valid_out && pdm_signal_valid /* 3MHZ */);

  logic first_stage_valid_out;
  logic signed [15:0] first_stage_out;

  decimate first_decimate(
    .clk(clk_m),
    .rst(sys_rst),
    .valid_in(first_dec_in_valid),
    .data_in(first_fir_out),
    .valid_out(first_stage_valid_out), // should follows frequency of 786KHZ
    .data_out(first_stage_out) // should expect 786KHZ at 16 bit depths
  );

  // Stage 2:
  logic second_fir_valid_out;
  logic signed [15:0] second_fir_out;

  fir_module second_fir(
    .clk(clk_m),
    .rst(sys_rst),
    .enable(first_stage_valid_out),
    .data_in(first_stage_out),
    .valid_out(second_fir_valid_out),
    .out(second_fir_out)
  );

  logic second_dec_in_valid;
  assign second_dec_in_valid = (second_fir_valid_out && first_stage_valid_out /* 786KHZ */);

  logic second_stage_valid_out;
  logic signed [15:0] second_stage_out;

  decimate second_decimate(
    .clk(clk_m),
    .rst(sys_rst),
    .valid_in(second_dec_in_valid),
    .data_in(second_fir_out),
    .valid_out(second_stage_valid_out), // should follows frequency of 192KHZ
    .data_out(second_stage_out) // should expect 192KHZ at 16 bit depths
  );

  // Stage 3:
  logic third_fir_valid_out;
  logic signed [15:0] third_fir_out;

  fir_module third_fir(
    .clk(clk_m),
    .rst(sys_rst),
    .enable(second_stage_valid_out),
    .data_in(second_stage_out),
    .valid_out(third_fir_valid_out),
    .out(third_fir_out)
  );

  logic third_dec_in_valid;
  assign third_dec_in_valid = (third_fir_valid_out && second_stage_valid_out /* 192KHZ */);

  logic third_stage_valid_out;
  logic signed [15:0] third_stage_out;

  decimate third_decimate(
    .clk(clk_m),
    .rst(sys_rst),
    .valid_in(third_dec_in_valid),
    .data_in(third_fir_out),
    .valid_out(third_stage_valid_out), // should follows frequency of 48KHZ
    .data_out(third_stage_out) // should expect 48KHZ at 16 bit depths
  );

  // Stage 4:
  logic fourth_fir_valid_out;
  logic signed [15:0] fourth_fir_out;

  fir_module fourth_fir(
    .clk(clk_m),
    .rst(sys_rst),
    .enable(third_stage_valid_out),
    .data_in(third_stage_out),
    .valid_out(fourth_fir_valid_out),
    .out(fourth_fir_out)
  );

  logic fourth_dec_in_valid;
  assign fourth_dec_in_valid = (fourth_fir_valid_out && third_stage_valid_out /* 48KHZ */);

  logic fourth_stage_valid_out;
  // logic signed [15:0] fourth_stage_out;
  logic signed [15:0] lowpassed_out;

  decimate fourth_decimate(
    .clk(clk_m),
    .rst(sys_rst),
    .valid_in(fourth_dec_in_valid),
    .data_in(fourth_fir_out),
    .valid_out(fourth_stage_valid_out), // should follows frequency of 12KHZ
    .data_out(lowpassed_out) // should expect 12KHZ at 16 bit depths
  );
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


  //choose which signal to play:
  // logic [7:0] audio_data_sel;

  // always_comb begin
  //   if (sw[0])begin
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


  // logic signed [7:0] vol_out; //can be signed or not signed...doesn't really matter
  logic signed [15:0] vol_out;
  // all this does is convey the output of vol_out to the input of the pdm
  // since it isn't used directly with any sort of math operation its signedness
  // is not as important.
  volume_control vc (.vol_in(sw[15:13]),.signal_in(lowpassed_out), .signal_out(vol_out));


  //PDM:
  logic pdm_out_signal; //an inherently digital signal (0 or 1..no need to make signed)
  //the value is encoded using Pulse Density Modulation
  logic audio_out; //value that drives output channels directly

  pdm my_pdm(
    .clk_in(clk_m),
    .rst_in(sys_rst),
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
      1'b0: audio_out = 0;
    endcase
  end

  assign spkl = audio_out;
  assign spkr = audio_out;

endmodule // top_level

//Volume Control
module volume_control (
  input wire [2:0] vol_in,
  input wire signed [15:0] signal_in,
  output logic signed [15:0] signal_out);
    logic [2:0] shift;
    assign shift = 3'd7 - vol_in;
    assign signal_out = signal_in>>>shift;
endmodule

`default_nettype wire
