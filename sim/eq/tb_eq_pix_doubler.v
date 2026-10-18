`timescale 1ns / 1ps

// pix_doubler.vhd against kg_pix_doubler.v: random load / shift / pixels, quad changing now and
// then; dout compared after every clock. Ends with "tb_eq_pix_doubler: N errors".

module tb_eq_pix_doubler;

parameter N = 100000;
`include "eq_check.vh"

reg clk = 1'b0;
always #10 clk = ~clk;

reg load = 1'b0, shift = 1'b0;
reg [7:0] d = 8'd0;
reg [1:0] quad = 2'd0;
wire old_q, new_q;

pix_doubler old_dut(.CLK(clk), .LOAD(load), .SHIFT(shift), .D(d), .QUAD(quad), .DOUT(old_q));
kg_pix_doubler new_dut(.clk(clk), .load(load), .shift(shift), .d(d), .quad(quad), .dout(new_q));

integer seed = 5;
reg [31:0] r;
always @(negedge clk) begin
	r = $random(seed);
	load <= (r[4:0] == 0);
	shift <= r[5] | r[6];
	d <= r[15:8];
	if (r[27:20] == 0) quad <= r[29:28];
end

reg started = 1'b0;
always @(negedge clk) if (started) eq_check("DOUT", old_q, new_q);

initial begin
	repeat (2) @(negedge clk);
	load = 1'b1;
	@(negedge clk);
	started = 1'b1;
	repeat (N) @(posedge clk);
	$display("tb_eq_pix_doubler: %0d checks", checks);
	$display("tb_eq_pix_doubler: %0d errors", errors);
	$finish;
end

endmodule
