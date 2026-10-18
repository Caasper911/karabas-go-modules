`timescale 1ns / 1ps

// pcm5102.v (module PCM5102): the I2S stream as the DAC reads it.
// - lrck period 256 clocks, bck period 8 clocks (DAC_CLK_DIV_BITS 1), lrck low = left;
// - din sampled at the rising bck edge, as it was in the bck low phase (din changes with the
//   falling bck, except in the first slot of a word, see below);
// - I2S: the first bck after an lrck edge is the last bit of the previous word, then bits 15..1
//   of the word.
// Each sample pair is held for 4 lrck periods, a word is checked in the 2nd and 3rd period.
//
// What pcm5102.v sends (STRICT = 0 checks bits 15..1 only):
// - bit 0 never: the first slot of a word carries index 16 of a 16-bit register, X here, bit 0
//   of the same channel's register after XST truncates the index, and it changes together with
//   the rising bck (the DAC takes either the old or the new channel's bit 0). The DAC sees 15
//   bits and the LSB of the other channel.
// - the registers are loaded during the last slot of the right word: on a sample change, bit 1
//   of the right word goes from the old to the new sample together with the rising bck.
// STRICT = 1 checks all 16 bits, for a fixed module.
// `define KG_PCM5102: kg_pcm5102.v, strict, and every frame: the frame in which the inputs
// change carries the pair before (taken at the start of the left word), the next ones the new.
// Ends with "tb_pcm5102: N errors".

module tb_pcm5102;

`ifdef KG_PCM5102
parameter STRICT = 1;
`else
parameter STRICT = 0;
`endif
parameter PAIRS = 40;

reg clk = 1'b0;
always #17.86 clk = ~clk; // 28 MHz

reg reset = 1'b1;
reg [15:0] left = 16'd0, right = 16'd0;
wire din, bck, lrck;

`ifdef KG_PCM5102
kg_pcm5102 #(.DIV_BITS(1)) dut(
`else
PCM5102 #(.DAC_CLK_DIV_BITS(1)) dut(
`endif
	.clk(clk), .reset(reset), .left(left), .right(right), .din(din), .bck(bck), .lrck(lrck)
);

integer errors = 0;

// ---------------- clock periods ----------------

integer clocks = 0;
integer bck_last = 0, lrck_last = 0, n_bck = 0, n_lrck = 0;
always @(posedge clk) clocks = clocks + 1;
always @(posedge bck) begin
	if (n_bck > 2 && clocks - bck_last != 8) begin
		if (errors < 10) $display("%t ERROR: bck period %0d clocks", $time, clocks - bck_last);
		errors = errors + 1;
	end
	bck_last = clocks;
	n_bck = n_bck + 1;
end
always @(negedge lrck) begin
	if (n_lrck > 2 && clocks - lrck_last != 256) begin
		if (errors < 10) $display("%t ERROR: lrck period %0d clocks", $time, clocks - lrck_last);
		errors = errors + 1;
	end
	lrck_last = clocks;
	n_lrck = n_lrck + 1;
end

// ---------------- I2S receiver ----------------

reg din_lo;
always @(negedge clk) if (!bck) din_lo <= din;
`ifdef KG_PCM5102
// din changes with the falling bck only
always @(posedge bck) #1 if (n_bck > 2 && din !== din_lo) begin
	if (errors < 10) $display("%t ERROR: din changed with the rising bck", $time);
	errors = errors + 1;
end
`endif

reg lr_prev = 1'b1;
integer slot = 0;
reg [15:0] sh = 16'd0;
reg [15:0] word_l, word_r;   // bits 15..1 of the last word, bit 0 from the first slot after it
reg got_l = 1'b0, got_r = 1'b0;
always @(posedge bck) begin
	if (lrck != lr_prev) begin
		// the first slot: bit 0 of the word just finished
		if (lr_prev) begin word_r = { sh[14:0], din_lo }; got_r = 1'b1; end
		else begin word_l = { sh[14:0], din_lo }; got_l = 1'b1; end
		slot = 1;
		lr_prev = lrck;
	end
	else begin
		sh = { sh[14:0], din_lo };
		slot = slot + 1;
	end
end

// ---------------- stimulus and check ----------------

reg [15:0] mask, prev_l, prev_r, exp_l, exp_r;
integer p, f, seed = 7;
initial begin
	mask = STRICT ? 16'hFFFF : 16'hFFFE;
	repeat (4) @(posedge clk);
	reset = 1'b0;
	for (p = 0; p < PAIRS; p = p + 1) begin
		@(negedge lrck); // a new frame: change the inputs in the middle of its left word
		repeat (64) @(posedge clk);
		prev_l = left;
		prev_r = right;
		left = $random(seed);
		right = $random(seed);
		if (p == 0) begin left = 16'h8001; right = 16'h7FFE; end
		for (f = 0; f < 4; f = f + 1) begin
			got_l = 1'b0;
			got_r = 1'b0;
			// the words of a frame are complete with the first slot of the next frame
			@(negedge lrck);
			@(posedge bck);
			@(posedge bck);
			exp_l = (f == 0) ? prev_l : left;
			exp_r = (f == 0) ? prev_r : right;
			if (p > 0 && (f >= 2 || (`ifdef KG_PCM5102 1 `else 0 `endif))) begin
				if ((word_l & mask) !== (exp_l & mask)) begin
					if (errors < 10) $display("%t ERROR: frame %0d left %h, sent %h", $time, f, word_l, exp_l);
					errors = errors + 1;
				end
				if ((word_r & mask) !== (exp_r & mask)) begin
					if (errors < 10) $display("%t ERROR: frame %0d right %h, sent %h", $time, f, word_r, exp_r);
					errors = errors + 1;
				end
			end
		end
	end
	$display("tb_pcm5102: last words %h %h for %h %h (bit 0 not checked: %0d)", word_l, word_r, left, right, !STRICT);
	$display("tb_pcm5102: %0d errors", errors);
	$finish;
end

endmodule
