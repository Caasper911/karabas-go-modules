`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_async_fifo.v

 FIFO of 2^AW words between two clocks of any frequency and phase (PLAN.md 6.C): the write side on wclk, the
 read side on rclk. The pointers cross as Gray codes through two flip-flops each, so a pointer seen on the
 other side is a value it had (at most one step behind); full and empty are therefore pessimistic by the time
 of the synchroniser and never wrong. rd takes the oldest word into dout in the next rclk (as kg_fifo); rd while
 empty and wr while full do nothing. rcount: the words in the fifo as the read side sees them (the written ones
 up to two or three wclk late).
 The memory is a dual port LUT RAM for a few words (written on wclk, read into the dout register on rclk);
 a word is read only after its write pointer passed the synchroniser, at least two rclk after its write.
 wreset / rreset empty the fifo (asynchronous); release each of them on its own clock, and assert both: the side
 not reset still has its old pointer.
 Timing: the paths from the Gray pointer registers (wgray, rgray) and from the memory into the other clock are
 to be bounded with FROM-TO DATAPATHONLY to the smaller of the two periods (the synchroniser takes the pointer
 one clock later; the data of a word is stable from two clocks before it is read).
 XST, 27 x 16: 85 LUTs (22 of them memory: 4 RAM32M, 3 RAM16X1D), 65 flip-flops.
*/

module kg_async_fifo #(
	parameter DW = 8,
	parameter AW = 4  // 2^AW words, AW >= 2
) (
	input wire wclk,
	input wire wreset,
	input wire wr,
	input wire [DW-1:0] din,
	output wire full,

	input wire rclk,
	input wire rreset,
	input wire rd,
	output reg [DW-1:0] dout = {DW{1'b0}},
	output wire empty,
	output wire [AW:0] rcount
);

reg [DW-1:0] mem [0:(1<<AW)-1];

function [AW:0] gray2bin;
	input [AW:0] g;
	integer i;
	begin
		gray2bin[AW] = g[AW];
		for (i = AW - 1; i >= 0; i = i - 1)
			gray2bin[i] = gray2bin[i + 1] ^ g[i];
	end
endfunction

// ---------------- write side ----------------
reg [AW:0] wbin = {(AW+1){1'b0}}, wgray = {(AW+1){1'b0}};
reg [AW:0] rgray_w1 = {(AW+1){1'b0}}, rgray_w2 = {(AW+1){1'b0}};
wire do_wr = wr && !full;
wire [AW:0] wbin_next = wbin + {{AW{1'b0}}, do_wr};

// full: the write pointer is one lap ahead of the read pointer (Gray: the two top bits inverted)
assign full = (wgray == {~rgray_w2[AW:AW-1], rgray_w2[AW-2:0]});

always @(posedge wclk)
	if (do_wr)
		mem[wbin[AW-1:0]] <= din;

always @(posedge wclk or posedge wreset)
	if (wreset) begin
		wbin <= {(AW+1){1'b0}};
		wgray <= {(AW+1){1'b0}};
		rgray_w1 <= {(AW+1){1'b0}};
		rgray_w2 <= {(AW+1){1'b0}};
	end
	else begin
		wbin <= wbin_next;
		wgray <= wbin_next ^ (wbin_next >> 1);
		rgray_w1 <= rgray;
		rgray_w2 <= rgray_w1;
	end

// ---------------- read side ----------------
reg [AW:0] rbin = {(AW+1){1'b0}}, rgray = {(AW+1){1'b0}};
reg [AW:0] wgray_r1 = {(AW+1){1'b0}}, wgray_r2 = {(AW+1){1'b0}};
wire do_rd = rd && !empty;
wire [AW:0] rbin_next = rbin + {{AW{1'b0}}, do_rd};

assign empty = (rgray == wgray_r2);
assign rcount = gray2bin(wgray_r2) - rbin;

always @(posedge rclk)
	if (do_rd)
		dout <= mem[rbin[AW-1:0]];

always @(posedge rclk or posedge rreset)
	if (rreset) begin
		rbin <= {(AW+1){1'b0}};
		rgray <= {(AW+1){1'b0}};
		wgray_r1 <= {(AW+1){1'b0}};
		wgray_r2 <= {(AW+1){1'b0}};
	end
	else begin
		rbin <= rbin_next;
		rgray <= rbin_next ^ (rbin_next >> 1);
		wgray_r1 <= wgray;
		wgray_r2 <= wgray_r1;
	end

endmodule
