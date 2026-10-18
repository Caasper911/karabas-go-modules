`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_pix_doubler.v

 Pixel shifter of a character line, the Verilog port of pix_doubler.vhd: load takes 8 pixels
 (d[7] first), each shift moves to the next pixel, dout is the current one (load has priority).
 quad: 0 = each pixel once (8 shifts), 1 or 2 = twice (16), 3 = four times (32).
*/

module kg_pix_doubler (
	input wire clk,
	input wire load,
	input wire shift,
	input wire [7:0] d,
	input wire [1:0] quad,
	output wire dout
);

reg [7:0] s8 = 8'd0;
reg [15:0] s16 = 16'd0;
reg [31:0] s32 = 32'd0;

integer i;
always @(posedge clk) begin
	if (load) begin
		s8 <= d;
		for (i = 0; i < 8; i = i + 1) begin
			s16[i*2 +: 2] <= {2{d[i]}};
			s32[i*4 +: 4] <= {4{d[i]}};
		end
	end
	else if (shift) begin
		s8 <= { s8[6:0], 1'b0 };
		s16 <= { s16[14:0], 1'b0 };
		s32 <= { s32[30:0], 1'b0 };
	end
end

assign dout = (quad == 2'd0) ? s8[7] : (quad == 2'd3) ? s32[31] : s16[15];

endmodule
