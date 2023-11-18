`timescale 1ns / 1ps
`default_nettype none


module recorder(
  input wire clk_in,
  input wire rst_in,
  input wire signed [7:0] audio_in,
  input wire record_in,
  input wire audio_valid_in,
  output logic signed [7:0] single_out,
  output logic signed [7:0] echo_out
  );

  localparam PLAYBACK = 0;
  localparam RECORD = 1;

  localparam RAM_DEPTH = 65536;
  
  logic [3:0] state = PLAYBACK;
  logic [15:0] final_address;   // use to remember the last recorded address
  logic [15:0] addr_a; // use as the current address to read out from
  logic [15:0] addr_first_delay; // address of first delay
  logic [15:0] addr_second_delay; // address of second delay
  logic signed [7:0] out_a; // port a out
  logic signed [7:0] out_first_delay; // first delay out
  logic signed [7:0] out_second_delay; // second delay out
  logic first_delay_init;
  logic second_delay_init;

  always_ff @(posedge clk_in) begin
    if(rst_in)begin
      final_address <= 0;
      addr_a <= 0;
      single_out <= 0;
      echo_out <= 0;
      first_delay_init <= 0;
      second_delay_init <= 0;
    end

    case (state)
      PLAYBACK: begin
        if(record_in)begin
          state <= RECORD;
          final_address <= 0;
          addr_a <= 0;
          single_out <= 0;
          echo_out <= 0;
          

        end else begin
          if(audio_valid_in) begin
            addr_a <= addr_a + 1;
            single_out <= out_a;
            // addr_first_delay <= (addr_a > 1500) ? addr_a - 1500 : 0;
            // addr_second_delay <= (addr_a > 3000) ? addr_a - 3000 : 0;
            echo_out <= out_a + ((first_delay_init) ? out_first_delay >>> 1 : 0)  + ((second_delay_init) ? (out_second_delay>>>2) : 0);

            if(!first_delay_init) begin
              if(addr_a > 1500) begin
                addr_first_delay <= addr_a - 1500;
                first_delay_init <= 1;
              end
            end else begin
              addr_first_delay <= addr_first_delay + 1;
            end

            if(!second_delay_init)begin
              if(addr_a > 3000) begin
                  addr_second_delay <= addr_a - 3000;
                  second_delay_init <= 1;
              end
            end else begin
              addr_second_delay <= addr_second_delay + 1;
            end
          end

          if(addr_a == final_address) begin
              addr_a <= 0;
          end
          if(addr_first_delay == final_address) begin
              addr_first_delay <= 0;
          end
          if(addr_second_delay == final_address) begin
              addr_second_delay <= 0;
          end

        end
      end

      RECORD: begin
        if(record_in == 0) begin
          state <= PLAYBACK;
          addr_a <= 0;
          final_address <= addr_a;
          first_delay_init <= 0;
          second_delay_init <= 0;
        end else begin
          if(audio_valid_in && addr_a <= RAM_DEPTH) begin
            addr_a <= addr_a + 1;
          end
        end
      end
    endcase
  end
  //we've included an instance of a dual port RAM for you:
  //how you use it is up to you.
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8),
    .RAM_DEPTH(65536))
    audio_buffer (
    .addra(addr_a), // data
    .clka(clk_in),
    .wea(record_in&&audio_valid_in),
    .dina(audio_in),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(out_a),
    .addrb(addr_first_delay), //first delay address
    .dinb(8'b0),
    .clkb(clk_in),
    .web(1'b0),
    .enb(1'b1),
    .rstb(),
    .regceb(1'b1),
    .doutb(out_first_delay)  //first delay out
  );

  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8),
    .RAM_DEPTH(65536))
    audio_buffer_delay (
    .addra(addr_a), // data
    .clka(clk_in),
    .wea(record_in&&audio_valid_in),
    .dina(audio_in),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(),
    .addrb(addr_second_delay), //second delay address
    .dinb(8'b0),
    .clkb(clk_in),
    .web(1'b0),
    .enb(1'b1),
    .rstb(),
    .regceb(1'b1),
    .doutb(out_second_delay)  //second delay out
  );
endmodule

`default_nettype wire

