`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

module rom_async #(
    parameter WIDTH=8,
    parameter DEPTH=256,
    parameter INIT_F=`FPATH(sine_lut.mem),
    localparam ADDRW=$clog2(DEPTH)
    ) (
    input wire [ADDRW-1:0] addr,
    output logic [WIDTH-1:0] data
    );

    logic [WIDTH-1:0] memory [DEPTH];

    initial begin
        if (INIT_F != 0) begin
            $display("Creating rom_async from init file '%s'.", INIT_F);
            $readmemh(INIT_F, memory);
        end
    end

    always_comb data = memory[addr];
endmodule
`default_nettype wire