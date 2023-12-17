`timescale 1ns / 1ps
`default_nettype none


module pdm(
            input wire clk_in,
            input wire rst_in,
            input wire data_ready,
            input wire signed [7:0] level_in,
            input wire tick_in,
            output logic pdm_out
  );
  logic signed [8:0] flip_out;  //9 bits to account for overflow/underflow
  assign pdm_out = (flip_out[8]) ? 0:1;
  logic start_pdm;
  always_ff @(posedge clk_in) begin
    if(rst_in) begin
      flip_out <= 0;
      start_pdm <= 0;
    end else begin
      if(tick_in && start_pdm)begin
        //calculate flip_out
        flip_out <= level_in + flip_out - ((pdm_out) ? 9'sd127 : -9'sd128);
      end
      if(data_ready == 1'b1) begin
        start_pdm <= 1'b1;
      end
    end
  end

endmodule


`default_nettype wire
