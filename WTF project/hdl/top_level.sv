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
  input wire  mic_data, //microphone data
  input wire [7:0] pmoda, //receiver pin
  output logic [7:0] pmodb //transmitting pin
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


  logic transmit_btn; //signal used to trigger recording
  //definitely want this debounced:
  debouncer rec_deb(  .clk_in(clk_m),
                      .rst_in(sys_rst),
                      .dirty_in(btn[1]),
                      .clean_out(transmit_btn));

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

  always_ff @(posedge clk_m)begin
    if (pdm_signal_valid) begin
      // "1" = 00000...10000000    "0" = 111111...00000
      // fixed_point_in <= (mic_data==1'b1)? {8'b1,8'h0} : 0; 
      // fixed_point_in <= {{8{mic_data}},8'h00};
      fixed_point_in <= mic_data ? 127 : -128;
    end 
  end

  logic signed [7:0] tone_750; //output of sine wave of 750Hz
  sine_generator #(
    .RIGHTSHIFT(11)
  )my_750 (
    .clk_in(clk_m),
    .rst_in(sys_rst), //clock and reset
    .step_in(pdm_signal_valid), //trigger a phase step (rate at which you run sine generator)
    .amp_out(tone_750) //output phase in 2's complement
  );


  // beginning of 4 stage FIR filter
  logic first_valid_out;
  logic signed [15:0] first_data_out;

  logic [4:0]right_shift;
  assign right_shift = sw[3:0]; // Good setting [15:13] = 111      [3:0] = 1111

  // good setting

  // Stage 1:
  fir_and_decimate_new stage_one(
     .clk(clk_m),
     .rst(sys_rst),
     .right_shift(right_shift),
     .single_valid_in(pdm_signal_valid), // single cycle 3.072 MHz
     .data_in(fixed_point_in),
     .fad_valid_out(first_valid_out), // single cycle 768 KHz
     .fad_data_out(first_data_out)
  );

  // Stage 2:
  logic second_valid_out;
  logic signed [15:0] second_data_out;
  fir_and_decimate_new stage_two(
    .clk(clk_m),
    .rst(sys_rst),
    .right_shift(right_shift),
    .single_valid_in(first_valid_out), // single cycle 768 KHz
    .data_in(first_data_out),
    .fad_valid_out(second_valid_out), // single cycle 192 KHz
    .fad_data_out(second_data_out)
  );

  // Stage 3:
  logic third_valid_out;
  logic signed [15:0] third_data_out;

  fir_and_decimate_new stage_three(
    .clk(clk_m),
    .rst(sys_rst),
    .right_shift(right_shift),
    .single_valid_in(second_valid_out), // single cycle 192 KHz
    .data_in(second_data_out),
    .fad_valid_out(third_valid_out), // single cycle 48 KHz
    .fad_data_out(third_data_out)
  );

  // Stage 4:
  logic fourth_valid_out;
  logic signed [15:0] fourth_data_out;
 
  logic encode_block_valid;
  logic signed [15:0][7:0] encode_block;

  fir_and_decimate_new stage_four(
    .clk(clk_m),
    .rst(sys_rst),
    .right_shift(right_shift),
    .single_valid_in(third_valid_out), // single cycle 48 KHz
    .data_in(third_data_out),
    .fad_valid_out(fourth_valid_out), // single cycle 12 KHz
    .fad_data_out(fourth_data_out)
  );


  /* BLOCK CREATION */          // takes 16 cycles of 12 Khz
  create_block encode_block_m1(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .add_new(fourth_valid_out),
    .block_in_8(fourth_data_out[15:8]),
    .result_out(encode_block),
    .valid_out(encode_block_valid)
  );

  localparam key = 128'h2b28ab097eaef7cf15d2154f16a6883c;
  
  /* ENCODE */                  // should be fast
  logic encode_valid_out;
  logic signed [15:0][7:0] ciphered_block;
  cipher cipher_module(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .start(encode_block_valid),
    .block_in(encode_block),
    .key_in(key),
    .result_out(ciphered_block),
    .valid_out(encode_valid_out)
  );

  logic signed [7:0] selected_eight;             // The selected byte from the encoded block
  logic ready_to_send;

  destroy_block encode_stream_m1(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .start(encode_valid_out),
    .request(fourth_valid_out),
    .block_in(ciphered_block),
    .result_out(selected_eight),
    .valid_out(ready_to_send)
  );

  // TRANSMIT: PMODA[3]
  // RECEIVE: PMODB[3]

  logic transmit_out;
  logic transmit_busy;
  tx transmit_module(
    .clk_in(clk_m),                               // Clock in (98.3MHz)
    .rst_in(sys_rst),                           
    .valid_in(ready_to_send && transmit_btn), // Only transmit if button held down
    .audio_in(selected_eight),
    .out(transmit_out),
    .busy(transmit_busy)
  );

  assign pmodb[2] = transmit_out;
  
  logic receive_in;
  logic receive_in_clean;
  assign receive_in = pmoda[2];

  synchronizer s1
        ( .clk_in(clk_m),
          .rst_in(sys_rst),
          .us_in(receive_in),
          .s_out(receive_in_clean));

  
  logic signed [7:0] received_audio;
  logic [2:0] receive_error;
  logic [3:0] receive_state;
  logic received_valid;
  rx receive_module(
    .clk_in(clk_m),                 // Clock in (98.3 MHz).
    .rst_in(sys_rst),               // Reset in.
    .signal_in(receive_in_clean),   // Signal in.
    .code_out(received_audio),      // Where to place code once captured.
    .new_code_out(received_valid),  // Single-cycle indicator that new code is present!
    .error_out(receive_error),      // Output error codes for debugging.
    .state_out(receive_state)       // Current state out (helpful for debugging).
  );

  logic decode_block_valid;
  logic signed [15:0][7:0] decode_block;

  /* BLOCK CREATION */ 
  create_block decode_block_m1(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .add_new(received_valid),
    .block_in_8(received_audio),
    .result_out(decode_block),
    .valid_out(decode_block_valid)
  );

  logic signed [15:0][7:0] deciphered_block;
  logic decode_valid_out;
  /* DECIPHER */
  decipher decipher_module(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .start(decode_block_valid),
    .block_in(decode_block),
    .key_in(key),
    .deciphered_block(deciphered_block),
    .decipher_complete(decode_valid_out)
  );

  logic signed [7:0] decoded_audio;             // The selected byte from the decoded block
  logic ready_to_hear;

  destroy_block decode_stream_m1(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .start(decode_valid_out),
    .request(fourth_valid_out),
    .block_in(deciphered_block),
    .result_out(decoded_audio),
    .valid_out(ready_to_hear)
  );


  always_comb begin
    if (sw[4])begin
      vol_in = fourth_data_out[15:8];  //signed
    end else if (sw[5])begin
      vol_in = tone_750;         //signed
    end else if (sw[6])begin
      // vol_in = deciphered_audio; //signed
      if (ready_to_hear) begin
        vol_in = decoded_audio;
      end
    end else begin
      vol_in = mic_data;
    end
  end
  
  logic signed [7:0] vol_in;
  // assign vol_in = fourth_data_out;

  logic data_ready;
  assign data_ready = fourth_valid_out;
  // assign data_ready = ready_to_hear;
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
    .data_ready(data_ready),
    .level_in(vol_out),
    .tick_in(pdm_signal_valid),
    .pdm_out(pdm_out_signal)
  );

  assign audio_out = pdm_out_signal;

  // always_comb begin
  //   case (sw[5:4])
  //     // 2'b00: audio_out = pwm_out_signal;
  //     // 2'b00: audio_out = audio_out;
  //     1'b01: audio_out = pdm_out_signal;
  //     // 2'b10: audio_out = sampled_mic_data;
  //     1'b00: audio_out = mic_data;
  //   endcase
  // end

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