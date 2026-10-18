`timescale 1ns / 1ps

// audio_peaks.v: the frames to the mcu against a model, random samples, short period.
// - the highest ones' complement absolute value of each channel over the samples of a period,
//   shifted up by one bit: L ({70, peak, 0}) in the last clock of the period, R ({71, ...}) in the
//   first clock of the next one, no other cmd_wr;
// - a period is 2^PERIOD_BITS clocks, its first sample is the one of the R clock, the sample of
//   the L clock is in no period.
// Ends with "tb_audio_peaks: N errors".

module tb_audio_peaks;

parameter PERIOD_BITS = 6;
parameter PERIODS = 300;

reg clk = 1'b0;
always #17.86 clk = ~clk;

reg signed [15:0] l = 16'sd0, r = 16'sd0;
wire cmd_wr;
wire [23:0] cmd;

audio_peaks #(.PERIOD_BITS(PERIOD_BITS)) dut(.clk(clk), .audio_l(l), .audio_r(r), .cmd_wr(cmd_wr), .cmd(cmd));

integer errors = 0, frames = 0;

function [14:0] abs1(input [15:0] s);
	abs1 = s[14:0] ^ {15{s[15]}};
endfunction

// the counter of the module starts at 0: clock n of the simulation is cnt = n mod 2^PERIOD_BITS
integer n = 0;
reg [14:0] pl = 0, pr = 0;     // peaks of the period so far
reg [23:0] exp_cmd;
reg exp_wr;
always @(posedge clk) begin
	exp_wr = 1'b0;
	if (n % (1 << PERIOD_BITS) == (1 << PERIOD_BITS) - 1) begin
		exp_wr = 1'b1;
		exp_cmd = { 8'h70, pl, 1'b0 };
	end
	else if (n % (1 << PERIOD_BITS) == 0) begin
		exp_wr = 1'b1;
		exp_cmd = { 8'h71, pr, 1'b0 };
		pl = abs1(l);
		pr = abs1(r);
	end
	else begin
		if (abs1(l) > pl) pl = abs1(l);
		if (abs1(r) > pr) pr = abs1(r);
	end
	n = n + 1;
end

always @(negedge clk) begin
	if (cmd_wr !== exp_wr || (exp_wr && cmd !== exp_cmd)) begin
		if (errors < 10) $display("%t ERROR: cmd_wr %b cmd %h, expected %b %h", $time, cmd_wr, cmd, exp_wr, exp_cmd);
		errors = errors + 1;
	end
	if (cmd_wr) frames = frames + 1;
end

// random samples, now and then a full scale one (32767, -32768)
reg [31:0] rnd;
integer seed = 3;
always @(negedge clk) begin
	rnd = $random(seed);
	l <= (rnd[3:0] == 0) ? 16'h7FFF : (rnd[3:0] == 1) ? 16'h8000 : $random(seed) >>> (rnd[7:4]);
	r <= (rnd[11:8] == 0) ? 16'h8000 : $random(seed) >>> (rnd[15:12]);
end

initial begin
	repeat (PERIODS << PERIOD_BITS) @(posedge clk);
	@(negedge clk);
	$display("tb_audio_peaks: %0d frames", frames);
	$display("tb_audio_peaks: %0d errors", errors);
	$finish;
end

endmodule
