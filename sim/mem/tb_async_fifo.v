`timescale 1ps / 1ps

// kg_async_fifo with four pairs of clocks at once: the same frequency with the read clock a quarter period
// late, the same frequency nearly in phase (0.1 ns), the write clock faster (1.7x), the read clock faster (2.3x);
// wr / rd at random, both resets now and then. A model queue checks every word read (order and value), that
// no more than 2^AW words are ever in the fifo, that rcount never counts a word not yet written and that empty /
// full are not both set; inputs change at the falling edges. Then a stream (wr and rd always on, same frequency,
// reading from half full): no word lost, no stall. Ends with "tb_async_fifo: N errors".

module afifo_case #(
	parameter integer WHALF = 6250,   // half periods, ps
	parameter integer RHALF = 6250,
	parameter integer RPHASE = 0,     // the first rising edge of rclk after that of wclk, ps
	parameter integer SEED = 1,
	parameter integer STEPS = 200000
) (
	output reg done = 1'b0
);

integer errors = 0;

localparam DW = 16, AW = 3, N = 1 << AW;

reg wclk = 1'b0, rclk = 1'b0;
initial begin
	#(WHALF);
	forever #(WHALF) wclk = ~wclk;
end
initial begin
	#(WHALF + RPHASE + RHALF);
	forever #(RHALF) rclk = ~rclk;
end

reg wreset = 1'b1, rreset = 1'b1;
reg wr = 1'b0, rd = 1'b0;
reg [DW-1:0] din = {DW{1'b0}};
wire full, empty;
wire [DW-1:0] dout;
wire [AW:0] rcount;
kg_async_fifo #(.DW(DW), .AW(AW)) dut(.wclk(wclk), .wreset(wreset), .wr(wr), .din(din), .full(full),
	.rclk(rclk), .rreset(rreset), .rd(rd), .dout(dout), .empty(empty), .rcount(rcount));

// model: the words written (accepted at a wclk edge) and read (taken at an rclk edge)
reg [DW-1:0] q [0:65535];
integer qw = 0, qr = 0, seed = SEED, reads = 0, writes = 0;
reg check_dout = 1'b0;
reg [DW-1:0] expect = {DW{1'b0}};
integer wr_pct = 50, rd_pct = 50;

task automatic fail;
	input [8*40-1:0] what;
	begin
		errors = errors + 1;
		if (errors <= 10) $display("%t ERROR (case %0d): %0s", $time, SEED, what);
	end
endtask

always @(posedge wclk)
	if (!wreset && wr && !full) begin
		q[qw[15:0]] = din;
		qw = qw + 1;
		writes = writes + 1;
		if (qw - qr > N) fail("more words than the fifo holds");
	end
always @(posedge rclk) begin
	if (check_dout && dout !== expect) fail("wrong word");
	check_dout = 1'b0;
	if (!rreset && rd && !empty) begin
		if (qr >= qw) fail("read while empty");
		expect = q[qr[15:0]];
		check_dout = 1'b1;
		qr = qr + 1;
		reads = reads + 1;
	end
end
always @(negedge rclk)
	if (!rreset) begin
		if (rcount > qw - qr) fail("rcount counts words not written");
		if (full && empty) fail("full and empty");
	end

// stimulus at the falling edges
always @(negedge wclk) begin
	wr <= ({$random(seed)} % 100) < wr_pct;
	din <= $random(seed);
end
always @(negedge rclk)
	rd <= ({$random(seed)} % 100) < rd_pct;

integer i, stalls = 0, overflows = 0;
reg streaming = 1'b0;
initial begin
	repeat (4) @(negedge wclk);
	wreset = 1'b0;
	@(negedge rclk) rreset = 1'b0;
	for (i = 0; i < STEPS; i = i + 1) begin
		@(negedge wclk);
		if (i % 5000 == 0) begin // a new mix: mostly writing, mostly reading, both
			wr_pct = 10 + {$random(seed)} % 90;
			rd_pct = 10 + {$random(seed)} % 90;
		end
		if ({$random(seed)} % 20000 == 0) begin // reset both sides, released on their clocks
			wreset = 1'b1; rreset = 1'b1;
			@(negedge rclk); @(negedge wclk);
			qr = qw; check_dout = 1'b0;
			wreset = 1'b0;
			@(negedge rclk) rreset = 1'b0;
		end
	end
	done = 1'b1;
end

endmodule

module tb_async_fifo;

wire [3:0] done;
afifo_case #(.WHALF(6250), .RHALF(6250), .RPHASE(3125), .SEED(1)) c0(.done(done[0]));
afifo_case #(.WHALF(6944), .RHALF(6944), .RPHASE(100), .SEED(2)) c1(.done(done[1]));
afifo_case #(.WHALF(5000), .RHALF(8500), .RPHASE(1234), .SEED(3)) c2(.done(done[2]));
afifo_case #(.WHALF(11500), .RHALF(5000), .RPHASE(777), .SEED(4)) c3(.done(done[3]));

// the stream of hdmi_top: same frequency, unknown phase, wr always, rd from half full on
reg sclk_w = 1'b0, sclk_r = 1'b0;
always #6944 sclk_w = ~sclk_w;
initial begin #2900; forever #6944 sclk_r = ~sclk_r; end
reg s_reset = 1'b1, s_rd = 1'b0;
reg [15:0] s_din = 16'd0;
wire s_full, s_empty;
wire [15:0] s_dout;
wire [4:0] s_rcount;
kg_async_fifo #(.DW(16), .AW(4)) stream(.wclk(sclk_w), .wreset(s_reset), .wr(1'b1), .din(s_din), .full(s_full),
	.rclk(sclk_r), .rreset(s_reset), .rd(s_rd), .dout(s_dout), .empty(s_empty), .rcount(s_rcount));
always @(posedge sclk_w) if (!s_reset) s_din <= s_din + 16'd1;
integer s_errors = 0, s_words = 0;
reg [15:0] s_prev = 16'd0;
reg s_took = 1'b0, s_have = 1'b0;
always @(posedge sclk_r) begin
	if (s_took) begin // dout has the word taken at the edge before
		if (s_have && s_dout !== s_prev + 16'd1) begin
			s_errors = s_errors + 1;
			if (s_errors <= 10) $display("%t ERROR (stream): %h after %h", $time, s_dout, s_prev);
		end
		s_prev = s_dout;
		s_have = 1'b1;
		s_words = s_words + 1;
	end
	s_took = !s_reset && s_rd && !s_empty;
	if (!s_reset && ((s_rd && s_empty) || s_full)) begin
		s_errors = s_errors + 1;
		if (s_errors <= 10) $display("%t ERROR (stream): %0s", $time, s_full ? "full" : "empty while reading");
	end
end
always @(negedge sclk_r) if (!s_reset && !s_rd && s_rcount >= 8) s_rd <= 1'b1;
initial begin
	repeat (3) @(negedge sclk_w);
	s_reset = 1'b0;
end

initial begin
	wait (&done);
	$display("tb_async_fifo: words %0d / %0d / %0d / %0d, stream %0d", c0.reads, c1.reads, c2.reads, c3.reads, s_words);
	if (c0.reads < 50000 || c1.reads < 50000 || c2.reads < 30000 || c3.reads < 30000 || s_words < 100000) begin
		$display("ERROR: too few words, the test does not test");
		s_errors = s_errors + 1;
	end
	$display("tb_async_fifo: %0d errors", c0.errors + c1.errors + c2.errors + c3.errors + s_errors);
	$finish;
end

endmodule
