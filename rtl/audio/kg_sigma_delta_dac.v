`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_sigma_delta_dac.v

 First order sigma-delta DAC (Xilinx XAPP154), the Verilog port of dac.vhd: one output bit per
 clock, its average is din / 2^(MSBI+1). din is unsigned (offset binary); a low-pass on the pin
 makes the analog level. reset puts the integrator in the middle.
*/

module kg_sigma_delta_dac #(
	parameter MSBI = 15 // index of the top bit of din
) (
	input wire clk,
	input wire reset,
	input wire [MSBI:0] din,
	output reg dout = 1'b0
);

// no initial value, as dac.vhd: with one XST builds two adders instead of an accumulator, or
// latches when it is not the reset value
reg [MSBI+2:0] sigma;

// the feedback: the output bit, as 0 or 3 * 2^(MSBI+1)
wire [MSBI+2:0] delta_b = { sigma[MSBI+2], sigma[MSBI+2], {(MSBI+1){1'b0}} };
wire [MSBI+2:0] delta = { 2'b00, din } + delta_b;
wire [MSBI+2:0] sum = delta + sigma;

always @(posedge clk or posedge reset) begin
	if (reset) begin
		sigma <= { 2'b01, {(MSBI+1){1'b0}} };
		dout <= 1'b0;
	end
	else begin
		sigma <= sum;
		dout <= sigma[MSBI+2];
	end
end

endmodule
