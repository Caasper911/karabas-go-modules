`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_cursor.v

 Absolute mouse position from the reports of the mcu (MS_X / MS_Y / MS_Z deltas, MS_UPD toggles
 with each report, mcu.vhd), as the Kempston mouse wants it: the cursor.vhd of the cores.
 x grows to the right, y up (the delta of the mcu is negated), both 8 bits wrapping, start 7F.
 A report moves them in the second clock after the clock that sees MS_UPD toggle. b passes
 through.
 The wheel, as the cores had it:
   Z_W 4, Z_NEG 1, Z_ACC 1: tsconf, baseconf, menu (4 bits, negated delta, start 7)
   Z_W 4, Z_NEG 0, Z_ACC 1: profi
   Z_W 8, Z_NEG 0, Z_ACC 1, Z_SEXT 0: next (8 bits, the delta zero-extended, start 7F)
   Z_W 4, Z_NEG 0, Z_ACC 0: test (z is the last delta, not a position)
*/

module kg_cursor #(
	parameter Z_W = 4,     // bits of z
	parameter Z_NEG = 1,   // negate the wheel delta
	parameter Z_ACC = 1,   // z is a position (else the last delta)
	parameter Z_SEXT = 1   // with Z_W > 4: the delta sign-extended (else zero-extended)
) (
	input wire clk,
	input wire [7:0] ms_x,
	input wire [7:0] ms_y,
	input wire [3:0] ms_z,
	input wire [2:0] ms_b,
	input wire ms_upd,
	output reg [7:0] x = 8'h7F,
	output reg [7:0] y = 8'h7F,
	output wire [Z_W-1:0] z,
	output wire [2:0] b
);

reg flag = 1'b0, trigger = 1'b0;
reg [7:0] dx = 8'd0, dy = 8'd0;
reg [Z_W-1:0] dz = {Z_W{1'b0}};
reg [Z_W-1:0] zpos = (1 << (Z_W - 1)) - 1;

// the wheel delta at the width of z
wire [Z_W-1:0] z_ext;
generate
	if (Z_W > 4) begin : kg_cursor_zext
		assign z_ext = { {(Z_W - 4){Z_SEXT ? ms_z[3] : 1'b0}}, ms_z };
	end
	else begin : kg_cursor_z4
		assign z_ext = ms_z[Z_W-1:0];
	end
endgenerate

always @(posedge clk) begin
	trigger <= 1'b0;
	if (flag != ms_upd) begin
		flag <= ms_upd;
		trigger <= 1'b1;
		dx <= ms_x;
		dy <= -ms_y;
		dz <= Z_NEG ? -z_ext : z_ext;
	end
	if (trigger) begin
		x <= x + dx;
		y <= y + dy;
		zpos <= zpos + dz;
	end
end

assign z = Z_ACC ? zpos : dz;
assign b = ms_b;

endmodule
