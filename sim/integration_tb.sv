`timescale 1ns / 1ps
`default_nettype none

module integration_tb();
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

    logic signed [15:0] data_in;
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
        // RIGHT_SHIFT(6) => 24 khz
        //// RIGHT_SHIFT(7) => 12 khz
      .RIGHTSHIFT(10) // Slow sine at 12 Khz because 3 MHz / (2^(RIGHT_SHIFT+1))
    )
    sine_gen_low_freq(
        .clk_in(clk_100mhz),
        .rst_in(rst_in),
        .step_in(clk_3mhz),
        .amp_out(slow_sine)
    );

    
    logic pdm_out;
    pdm pdm_module
            ( .clk_in(clk_100mhz),
                .rst_in(rst_in),
                .data_ready(1'b1),
                .level_in(slow_sine),
                .tick_in(clk_3mhz),
                .pdm_out(pdm_out)
            );

    assign data_in = pdm_out ? {8'b1,8'h0} : 0; 
    
    logic signed [15:0] first_stage_data_in;
    assign first_stage_data_in = data_in;
    logic first_stage_valid_out;
    logic signed [15:0] first_stage_data_out;
    logic [4:0] right_shift;
    assign right_shift = 5'd16;
    fir_and_decimate_new uut
    (
        .clk(clk_100mhz),
        .rst(rst_in),
        .right_shift(right_shift),
        .single_valid_in(clk_3mhz),
        .data_in(first_stage_data_in),
        .fad_valid_out(first_stage_valid_out),
        .fad_data_out(first_stage_data_out)
    );
    logic signed [15:0] second_stage_data_in;
    assign second_stage_data_in = first_stage_data_out;

    logic second_stage_valid_out;
    logic signed [15:0] second_stage_data_out;

    fir_and_decimate_new stage_two
    (
        .clk(clk_100mhz),
        .rst(rst_in),
        .right_shift(right_shift),
        .single_valid_in(first_stage_valid_out),
        .data_in(second_stage_data_in),
        .fad_valid_out(second_stage_valid_out),
        .fad_data_out(second_stage_data_out)
    );

    logic signed [15:0] third_stage_data_in;
    assign third_stage_data_in = second_stage_data_out;

    logic third_stage_valid_out;
    logic signed [15:0] third_stage_data_out;

    fir_and_decimate_new stage_three
    (
        .clk(clk_100mhz),
        .rst(rst_in),
        .right_shift(right_shift),
        .single_valid_in(second_stage_valid_out),
        .data_in(third_stage_data_in),
        .fad_valid_out(third_stage_valid_out),
        .fad_data_out(third_stage_data_out)
    );

    logic signed [15:0] fourth_stage_data_in;
    assign fourth_stage_data_in = third_stage_data_out;

    logic fourth_stage_valid_out;
    logic signed [15:0] fourth_stage_data_out;

    fir_and_decimate_new stage_four
    (
        .clk(clk_100mhz),
        .rst(rst_in),
        .right_shift(right_shift),
        .single_valid_in(third_stage_valid_out),
        .data_in(fourth_stage_data_in),
        .fad_valid_out(fourth_stage_valid_out),
        .fad_data_out(fourth_stage_data_out)
    );
    logic block_valid_out;
    logic [15:0][7:0] block;

    /* BLOCK CREATION */          // takes 16 cycles of 12 Khz
    create_block blocking_module(
        .clk_in(clk_100mhz),
        .rst_in(rst_in),
        .start(fourth_stage_valid_out),
        .block_in_8(fourth_stage_data_out),
        .result_out(block),
        .valid_out(block_valid_out)
    );
    localparam key = 128'h2b28ab097eaef7cf15d2154f16a6883c;
    
    /* ENCODE */                  // should be fast
    logic encode_valid_out;
    logic [15:0][7:0] encoded_block;
    cipher cipher_module(
        .clk_in(clk_100mhz),
        .rst_in(rst_in),
        .start(block_valid_out),
        .block_in(block),
        .key_in(key),
        .result_out(encoded_block),
        .valid_out(encode_valid_out)
    );

    localparam TRANSMIT_IDLE = 0;
    localparam TRANSMIT = 1;
    localparam TRANSMIT_BOUND = 16;
    logic transmit_state;
    logic [$clog2(16):0] byte_counts;
    always_ff @(posedge clk_m) begin
        if(sys_rst) begin
        transmit_state <= TRANSMIT_IDLE;
        byte_counts <= 0;
        end else begin
        case (transmit_state) 
            TRANSMIT_IDLE: begin
            if(encode_valid_out == 1'b1) begin
                transmit_state <= TRANSMIT;
                byte_counts <= 0;
            end
            end
            TRANSMIT: begin
                ready_to_transmit <= 1'b0;
                
                // 12 KHz single cycle valid
                if(fourth_valid_out == 1'b1) begin
                    byte_counts <= byte_counts + 1;
                    
                    // Grab the chunk of byte to transmit
                    selected_eight <= encoded_block[byte_counts];

                    // let the transmit module know that it should transmit the selected_eight
                    ready_to_transmit <= 1'b1;
                end
                if(byte_counts == TRANSMIT_BOUND - 1) begin
                    transmit_state <= TRANSMIT_IDLE;
                end
            end
        endcase
        end
    end


    logic signed [7:0] selected_eight;             // The selectd byte from the encoded block
    logic ready_to_transmit;                      // Single cycle valid (12KHz)

    logic transmit_out;
    logic transmit_busy;

    // assign selected_eight = fourth_stage_data_out;
    // assign ready_to_transmit = fourth_stage_valid_out;
    tx transmit_module(
        .clk_in(clk_100mhz),                               // Clock in (98.3MHz)
        .rst_in(rst_in),                           
        .valid_in(ready_to_transmit),                      // Only transmit if button held down
        .audio_in(selected_eight),
        .out(transmit_out),
        .busy(transmit_busy)
    );

    logic receive_in;
    assign receive_in = transmit_out;

    logic signed [7:0]received_audio;
    logic [2:0] receive_error;
    logic [3:0] receive_state;
    logic received_valid;

    rx receive_module(
        .clk_in(clk_100mhz),                 // Clock in (98.3 MHz).
        .rst_in(rst_in),               // Reset in.
        .signal_in(receive_in),         // Signal in.
        .code_out(received_audio),      // Where to place code once captured.
        .new_code_out(received_valid),  // Single-cycle indicator that new code is present!
        .error_out(receive_error),      // Output error codes for debugging.
        .state_out(receive_state)       // Current state out (helpful for debugging).
    );
    
    logic [15:0][7:0] receive_block;
    logic receive_block_valid;
    create_block blocking_module_receiving(
        .clk_in(clk_100mhz),
        .rst_in(rst_in),
        .start(received_valid),
        .block_in_8(received_audio),
        .result_out(receive_block),
        .valid_out(receive_block_valid)
    );


    logic [15:0][7:0] deciphered_block;
    logic decipher_valid;
    /* DECIPER */
    decipher decipher_module(
        .clk_in(clk_m),
        .rst_in(sys_rst),
        .start(receive_block_valid),
        .block_in(receive_block),
        .key_in(key),
        .result_out(deciphered_block),
        .valid_out(decipher_valid)
    );

    logic signed [7:0] deciphered_audio;
    logic ready_to_hear;
    localparam BREAK_IDLE = 0;
    localparam BREAK = 1;
    localparam BREAK_BOUND = 16;
    logic break_state;
    logic [$clog2(16):0] byte_counts_2;
    always_ff @(posedge clk_m) begin
        if(sys_rst) begin
        break_state <= BREAK_IDLE;
        byte_counts_2 <= 0;
        end else begin
        case (break_state) 
            BREAK_IDLE: begin
            if(decipher_valid == 1'b1) begin
                break_state <= BREAK;
                byte_counts_2 <= 0;
            end
            end
            BREAK: begin
            ready_to_hear <= 1'b0;

            // 12 KHz single cycle valid
            if(fourth_valid_out == 1'b1 && byte_counts_2 < BREAK_BOUND - 1) begin
                byte_counts_2 <= byte_counts_2 + 1;
                
                // Grab the chunk of byte to transmit
                deciphered_audio <= deciphered_block[byte_counts_2];

                // let the transmit module know that it should transmit the selected_eight
                ready_to_hear <= 1'b1;
            end
            if(byte_counts_2 == BREAK_BOUND - 1) begin
                break_state <= BREAK_IDLE;
            end
            end
        endcase
        end
    end

    // logic signed [7:0] pdm_in;
    // assign pdm_in = fourth_stage_data_out;
    // logic final_pdm_out;
    // pdm pdm_module_final
    //         (   .clk_in(clk_100mhz),
    //             .rst_in(rst_in),
    //             .data_ready(fourth_stage_valid_out),
    //             .level_in(pdm_in),
    //             .tick_in(clk_3mhz),
    //             .pdm_out(final_pdm_out)
    //         );
    
    

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
    $dumpfile("integration.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,integration_tb);
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