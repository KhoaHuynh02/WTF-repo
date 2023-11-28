`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module sine_wave_gen(
    input wire clk,
    input wire rst_in,
    output logic signed [15:0]data_out
);
    logic [4:0] state_reg;
    logic [3:0] cntr;
    
    localparam wvfm_period = 4'd4;
    localparam init               = 5'd0;
    localparam sendSample0        = 5'd1;
    localparam sendSample1        = 5'd2;
    localparam sendSample2        = 5'd3;
    localparam sendSample3        = 5'd4;
    localparam sendSample4        = 5'd5;
    localparam sendSample5        = 5'd6;
    localparam sendSample6        = 5'd7;
    localparam sendSample7        = 5'd8;

    always_ff @(posedge clk)begin
      if (rst_in == 1'b1)
          begin
              cntr <= 4'd0;
              data_out <= 16'd0;
              state_reg <= init;
          end
      else
          begin
              case (state_reg)
                  init : //0
                      begin
                          cntr <= 4'd0;
                          data_out <= 16'sh0000;
                          state_reg <= sendSample0;
                      end
                      
                  sendSample0 : //1
                      begin
                          data_out <= 16'sh0000;
                          
                          if (cntr == wvfm_period)
                              begin
                                  cntr <= 4'd0;
                                  state_reg <= sendSample1;
                              end
                          else
                              begin 
                                  cntr <= cntr + 1;
                                  state_reg <= sendSample0;
                              end
                      end 
                  
                  sendSample1 : //2
                      begin
                          data_out <= 16'sh5A7E; 
                          
                          if (cntr == wvfm_period)
                              begin
                                  cntr <= 4'd0;
                                  state_reg <= sendSample2;
                              end
                          else
                              begin 
                                  cntr <= cntr + 1;
                                  state_reg <= sendSample1;
                              end
                      end 
                  
                  sendSample2 : //3
                      begin
                          data_out <= 16'sh7FFF;
                          
                          if (cntr == wvfm_period)
                              begin
                                  cntr <= 4'd0;
                                  state_reg <= sendSample3;
                              end
                          else
                              begin 
                                  cntr <= cntr + 1;
                                  state_reg <= sendSample2;
                              end
                      end 
                  
                  sendSample3 : //4
                      begin
                          data_out <= 16'sh5A7E;
                          
                          if (cntr == wvfm_period)
                              begin
                                  cntr <= 4'd0;
                                  state_reg <= sendSample4;
                              end
                          else
                              begin 
                                  cntr <= cntr + 1;
                                  state_reg <= sendSample3;
                              end
                      end 
                  
                  sendSample4 : //5
                      begin
                          data_out <= 16'sh0000;
                          
                          if (cntr == wvfm_period)
                              begin
                                  cntr <= 4'd0;
                                  state_reg <= sendSample5;
                              end
                          else
                              begin 
                                  cntr <= cntr + 1;
                                  state_reg <= sendSample4;
                              end
                      end 
                  
                  sendSample5 : //6
                      begin
                          data_out <= 16'shA582; 
                          
                          if (cntr == wvfm_period)
                              begin
                                  cntr <= 4'd0;
                                  state_reg <= sendSample6;
                              end
                          else
                              begin 
                                  cntr <= cntr + 1;
                                  state_reg <= sendSample5;
                              end
                      end 
                  
                  sendSample6 : //6
                      begin
                          data_out <= 16'sh8000; 
                          
                          if (cntr == wvfm_period)
                              begin
                                  cntr <= 4'd0;
                                  state_reg <= sendSample7;
                              end
                          else
                              begin 
                                  cntr <= cntr + 1;
                                  state_reg <= sendSample6;
                              end
                      end 
                  
                  sendSample7 : //6
                      begin
                          data_out <= 16'shA582; 
                          
                          if (cntr == wvfm_period)
                              begin
                                  cntr <= 4'd0;
                                  state_reg <= sendSample0;
                              end
                          else
                              begin 
                                  cntr <= cntr + 1;
                                  state_reg <= sendSample7;
                              end
                      end                       
              endcase
          end
    end
    
endmodule

`default_nettype wire