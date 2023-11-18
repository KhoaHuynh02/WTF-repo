`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

// assumming that the information comes in at 12khz at 8 bits depth
module transmit (
    input wire clk_in, // 98.3 MHZ ~ 10ns
    input wire rst_in,
    input wire record_done,
    input wire [7:0] audio_in, // audio data in
    input wire audio_valid_in, //12 khz
    output logic valid_out,
    output logic out
);
    localparam IDLE = 0;
    localparam SYNC = 1;
    localparam SEND = 2;

    localparam SYNC_LOW = 400; // 400 of 10 ns
    localparam SYNC_HIGH = 600; // 600 of 10 ns
    localparam MAX_COUNTER = SYNC_LOW + SYNC_HIGH;

    localparam LOW = 200;
    localparam ZERO_LEVEL = LOW + 200;
    localparam ONE_LEVEL = LOW + 600;

    logic [1:0] state = IDLE;
    logic [7:0] audio_buffer <= 0;
    logic [$clog2(MAX_COUNTER)-1:0] counter;
    logic [$clog2(8)-1:0] bits_sent = 0;


    always_ff @(posedge clk_in ) begin
        if(rst_in) begin
            //reset variables and states
            state <= IDLE;
            audio_buffer <= 0;
            counter <= 0;
            bits_sent <= 0;
            valid_out <= 0;
            out <= 0;
        end

        case(state)
            IDLE: begin
                // upon receiving a valid audio every 12khz
                // start the process of sending
                if(audio_valid_in) begin
                    state <= SYNC;
                    audio_buffer <= audio_in; // load in the audio to buffer
                    counter <= 0;
                    bits_sent <= 0;
                    valid_out <= 1;
                    out <= 0;
                end
            end
            
            SYNC: begin
                // counter that counts how many 10ns passed
                counter = counter + 1;
                assert(valid_out == 1);
                // threshold for the low of the sync
                if(counter == SYNC_LOW) begin
                    out <= 1;
                end 
                // mark the end of the sync signal, start sending
                else if (counter == SYNC_LOW + SYNC_HIGH) begin
                    state <= SEND;
                    counter <= 0;
                    bits_sent <= 0;
                    valid_out <= 1;
                    out <= 0;
                end
            end

            SEND: begin
                // counter that counts how many 10ns passed
                counter = counter + 1;
                assert(valid_out == 1);
                // if we have sent 8 bits then we are done for 1 cycle
                if(bits_sent >= 8) begin
                    state <= IDLE;
                    audio_buffer <= 0;
                    counter <= 0;
                    bits_sent <= 0;
                    valid_out <= 0;
                    out <= 0;
                end 
                else begin
                    // transition out of LOW
                    if(counter == LOW) begin
                        out <= 1;
                    end

                    // encoding for "0"
                    if(audio_buffer[7] == 1'b0) begin
                        if (counter == ZERO_LEVEL) begin
                            audio_buffer <= audio_buffer << 1;
                            counter <= 0;
                            bits_sent <= bits_sent + 1; // successfully sent a bit
                            out <= 0; // end of "0" frame
                        end
                    end 
                    // encoding for "1"
                    else begin
                        if (counter == ONE_LEVEL) begin
                            audio_buffer <= audio_buffer << 1;
                            counter <= 0;
                            bits_sent <= bits_sent + 1;
                            out <= 0;
                        end
                    end
                end
            end        
        endcase
    end

endmodule

`default_nettype wire