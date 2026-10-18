`timescale 1ns / 1ps

// The cursor.vhd of tsconf, profi, next and test (sim/eq/ref) against kg_cursor.v with their
// parameters: random mouse reports, MS_UPD toggled at random gaps (also in consecutive clocks);
// every output compared after every clock. Ends with "tb_eq_cursor: N errors".

module tb_eq_cursor;

parameter N = 100000;
`include "eq_check.vh"

reg clk = 1'b0;
always #10 clk = ~clk;

reg [7:0] mx = 8'd0, my = 8'd0;
reg [3:0] mz = 4'd0;
reg [2:0] mb = 3'd0;
reg upd = 1'b0;

`define REF(name, zw) \
	wire [7:0] name``_ox, name``_x, name``_oy, name``_y; \
	wire [zw-1:0] name``_oz, name``_z; \
	wire [2:0] name``_ob, name``_b; \
	cursor_``name old_``name(.CLK(clk), .RESET(1'b0), .MS_X(mx), .MS_Y(my), .MS_Z(mz), .MS_B(mb), .MS_UPD(upd), \
		.OUT_X(name``_ox), .OUT_Y(name``_oy), .OUT_Z(name``_oz), .OUT_B(name``_ob));

`REF(tsconf, 4)
`REF(profi, 4)
`REF(next, 8)
`REF(test, 4)

kg_cursor #(.Z_W(4), .Z_NEG(1), .Z_ACC(1)) new_tsconf(.clk(clk), .ms_x(mx), .ms_y(my), .ms_z(mz), .ms_b(mb), .ms_upd(upd),
	.x(tsconf_x), .y(tsconf_y), .z(tsconf_z), .b(tsconf_b));
kg_cursor #(.Z_W(4), .Z_NEG(0), .Z_ACC(1)) new_profi(.clk(clk), .ms_x(mx), .ms_y(my), .ms_z(mz), .ms_b(mb), .ms_upd(upd),
	.x(profi_x), .y(profi_y), .z(profi_z), .b(profi_b));
kg_cursor #(.Z_W(8), .Z_NEG(0), .Z_ACC(1), .Z_SEXT(0)) new_next(.clk(clk), .ms_x(mx), .ms_y(my), .ms_z(mz), .ms_b(mb), .ms_upd(upd),
	.x(next_x), .y(next_y), .z(next_z), .b(next_b));
kg_cursor #(.Z_W(4), .Z_NEG(0), .Z_ACC(0)) new_test(.clk(clk), .ms_x(mx), .ms_y(my), .ms_z(mz), .ms_b(mb), .ms_upd(upd),
	.x(test_x), .y(test_y), .z(test_z), .b(test_b));

`define CMP(name) \
	eq_check(`"name x`", name``_ox, name``_x); \
	eq_check(`"name y`", name``_oy, name``_y); \
	eq_check(`"name z`", name``_oz, name``_z); \
	eq_check(`"name b`", name``_ob, name``_b);

always @(negedge clk) begin
	`CMP(tsconf)
	`CMP(profi)
	`CMP(next)
	`CMP(test)
end

integer seed = 21, gap = 0;
reg [31:0] r;
always @(negedge clk) begin
	r = $random(seed);
	if (gap == 0) begin
		mx <= r[7:0];
		my <= r[15:8];
		mz <= r[19:16];
		mb <= r[22:20];
		upd <= ~upd;
		gap = r[23] ? 0 : r[29:24];
	end
	else
		gap = gap - 1;
end

initial begin
	repeat (N) @(posedge clk);
	$display("tb_eq_cursor: %0d checks", checks);
	$display("tb_eq_cursor: %0d errors", errors);
	$finish;
end

endmodule
