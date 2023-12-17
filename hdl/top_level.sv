`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

/* 
    WTF: Walkie-Talkie on FPGA
    Created by: Khoa Huynh, Khang Le, Keawe Mann
    6.205 Fall 2023
*/

/*
    Important information:

    Pin connections:
    - Transmission pin is on pmodb[2]
    - Reception pin is on pmoda[2]

    RGB LED indicator:
    - Left blue LED: walkie-talkie mode
    - Right red LED: microphone mode
    - Toggle mode by pressing btn[2]

    Key selection:
    - AES encryption key is selected by the switch bank
    - BE CAREFUL: wrong key will result in a loud, disorienting
      audio output
      
*/

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
  assign rgb0 = {2'b00, ~toggle};
  assign rgb1 = {toggle, 2'b00};

  logic sys_rst;
  assign sys_rst = btn[0];

  logic clk_m;
  audio_clk_wiz macw (.clk_in(clk_100mhz), .clk_out(clk_m)); //98.3MHz
  // we make 98.3 MHz since that number is cleanly divisible by
  // 32 to give us 3.072 MHz.  3.072 MHz is nice because it is cleanly divisible
  // by nice powers of 2 to give us reasonable audio sample rates. For example,
  // a decimation by a factor of 64 could give us 6 bit 48 kHz audio
  // a decimation by a factor of 256 gives us 8 bit 12 kHz audio
  // we do the latter in this lab.


  logic transmit_btn; //signal used to trigger transmission
  //definitely want this debounced:
  debouncer tx_deb(  .clk_in(clk_m),
                      .rst_in(sys_rst),
                      .dirty_in(btn[1]),
                      .clean_out(transmit_btn));


  logic audio_toggle; //signal used to toggle between audio sources
  debouncer toggle_deb(.clk_in(clk_m),
                      .rst_in(sys_rst),
                      .dirty_in(btn[2]),
                      .clean_out(audio_toggle));

  localparam PDM_COUNT_PERIOD = 32; //
  logic old_mic_clk; //prior mic clock for edge detection
  
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
      fixed_point_in <= mic_data ? 127 : -128;
    end 
  end

  // beginning of 4 stage FIR filter
  logic first_valid_out;
  logic signed [15:0] first_data_out;

  logic [4:0] right_shift;
  assign right_shift = 5'b01101; // Good setting [15:13] = 111      [3:0] = 1111

  // good setting

  // Stage 1:
  fir_decimate stage_one(
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
  fir_decimate stage_two(
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

  fir_decimate stage_three(
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

  fir_decimate stage_four(
    .clk(clk_m),
    .rst(sys_rst),
    .right_shift(right_shift),
    .single_valid_in(third_valid_out), // single cycle 48 KHz
    .data_in(third_data_out),
    .fad_valid_out(fourth_valid_out), // single cycle 12 KHz
    .fad_data_out(fourth_data_out)
  );

  logic signed [7:0] audio_in;
  assign audio_in = fourth_data_out[15:8];

  logic clk_12khz;
  assign clk_12khz = fourth_valid_out;

  /* BLOCK CREATION */          // takes 16 cycles of 12 Khz
  logic encode_block_valid;
  logic signed [15:0][7:0] encode_block;

  create_block blocking(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .add_new(clk_12khz),
    .block_in_8(audio_in),
    .result_out(encode_block),
    .valid_out(encode_block_valid)
  );
  
  logic [15:0][7:0] key;

  always_comb begin
    for (integer i=0; i<16; i=i+1) begin
      key[i] = {8{sw[i]}};
    end
  end

  /* ENCODE */                  // should be fast
  logic encode_valid;
  logic signed [15:0][7:0] encoded_block;
  cipher encoding(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .start(encode_block_valid),
    .block_in(encode_block),
    .key_in(key),
    .result_out(encoded_block),
    .valid_out(encode_valid)
  );

  logic transmit_out;
  logic transmit_busy;
  
  localparam SBD = 500;  // Sync burst duration.
  localparam SSD = 500;  // Sync silence duration.
  localparam BBD = 300;  // Bit burst duration.
  localparam BSD0 = 150;  // Bit silence duration (for 0).
  localparam BSD1 = 300;  // Bit silence duration (for 1).
  localparam MARGIN = 50;  // The +/- of your signals.
  localparam WIDTH = 128; // The bit depth of the output

  tx #(.SBD(SBD),
    .SSD(SSD),
    .BBD(BBD),
    .BSD0(BSD0),
    .BSD1(BSD1),
    .WIDTH(WIDTH)
    ) 
    transmit (
    .clk_in(clk_m),                               // Clock in (98.3MHz)
    .rst_in(sys_rst),                           
    .valid_in(encode_valid && transmit_btn), // Only transmit if button held down
    .signal_in(encoded_block),
    .out(transmit_out),
    .busy(transmit_busy)
  );

  // TRANSMIT: PMODB[3]
  // RECEIVE: PMODA[3]

  assign pmodb[2] = transmit_out;
  
  logic receive_in;
  logic receive_in_synced;
  assign receive_in = pmoda[2];

  synchronizer s1
        ( .clk_in(clk_m),
          .rst_in(sys_rst),
          .us_in(receive_in),
          .s_out(receive_in_synced));

  logic signed [WIDTH-1:0] received_audio;
  logic [2:0] receive_error;
  logic [3:0] receive_state;
  logic received_valid;

  rx #(.SBD(SBD),
    .SSD(SSD),
    .BBD(BBD),
    .BSD0(BSD0),
    .BSD1(BSD1),
    .MARGIN(MARGIN),
    .WIDTH(WIDTH)
    )
    receive (
    .clk_in(clk_m),                 // Clock in (98.3 MHz).
    .rst_in(sys_rst),               // Reset in.
    .signal_in(receive_in_synced),   // Signal in.
    .code_out(received_audio),      // Where to place code once captured.
    .new_code_out(received_valid),  // Single-cycle indicator that new code is present!
    .error_out(receive_error),      // Output error codes for debugging.
    .state_out(receive_state)       // Current state out (helpful for debugging).
  );

  logic signed [15:0][7:0] decoded_block;
  logic decode_valid;
  /* DECIPHER */
  decipher decoding(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .start(received_valid),
    .block_in(received_audio),
    .key_in(key),
    .deciphered_block(decoded_block),
    .decipher_complete(decode_valid)
  );

  logic signed [7:0] audio_stream;             // The selected byte from the decoded block
  logic audio_valid;

  destroy_block deblocking(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .start(decode_valid),
    .request(clk_12khz),
    .block_in(decoded_block),
    .result_out(audio_stream),
    .valid_out(audio_valid)
  );

  logic btn_pulse;
  logic prev;
  always_ff @(posedge clk_m) begin
    if (!prev & audio_toggle) begin
      btn_pulse <= 1'b1;
    end else begin
      btn_pulse <= 1'b0;
    end
    prev <= audio_toggle;
  end

  logic toggle;
  always_ff @(posedge clk_m) begin
    if (sys_rst) begin
      toggle <= 0;
    end else if (btn_pulse) begin
      toggle <= !toggle;
    end
  end
  
  logic signed [7:0] vol_in;
  
  always_comb begin
    if (toggle) begin
      if (audio_valid) begin
        vol_in = audio_stream;
      end
    end else begin
      vol_in = audio_in;
    end
  end

  logic data_ready;
  assign data_ready = clk_12khz;

  //PDM:
  logic audio_out; //value that drives output channels directly

  pdm my_pdm(
    .clk_in(clk_m),
    .rst_in(sys_rst),
    .data_ready(data_ready),
    .level_in(vol_in),
    .tick_in(pdm_signal_valid),
    .pdm_out(audio_out)
  );

  assign spkl = audio_out;
  assign spkr = audio_out;

endmodule // top_level

`default_nettype wire