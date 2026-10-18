`timescale 1ns / 1ps

// burst_rx.vhd against kg_burst_rx.v: random bursts (header, 0-40 data bytes), sck from 36 MHz to
// 10 MHz, random gaps, now and then a burst cut in the middle of a byte; every output compared
// after every clock and at the end of every byte. Ends with "tb_eq_burst_rx: N errors".

module tb_eq_burst_rx;

parameter BURSTS = 600;
`include "eq_check.vh"

reg clk = 1'b0;
always #17.65 clk = ~clk; // 28.33 MHz

reg sck = 1'b0, mosi = 1'b0, cs_n = 1'b1;
wire [7:0] old_type, new_type, old_data, new_data;
wire [31:0] old_addr, new_addr;
wire old_wr, new_wr, old_active, new_active;

burst_rx old_dut(.CLK(clk), .SCK(sck), .MOSI(mosi), .CS_N(cs_n),
	.TYPE_O(old_type), .ADDR_O(old_addr), .DATA_O(old_data), .WR_O(old_wr), .ACTIVE_O(old_active));
kg_burst_rx new_dut(.clk(clk), .sck(sck), .mosi(mosi), .cs_n(cs_n),
	.btype(new_type), .addr(new_addr), .data(new_data), .wr(new_wr), .active(new_active));

task automatic compare;
	begin
		eq_check("TYPE_O", old_type, new_type);
		eq_check("ADDR_O", old_addr, new_addr);
		eq_check("DATA_O", old_data, new_data);
		eq_check("WR_O", old_wr, new_wr);
		eq_check("ACTIVE_O", old_active, new_active);
	end
endtask
always @(negedge clk) compare;

integer seed = 9, half = 31, writes = 0;
always @(posedge clk) if (old_wr) writes = writes + 1;

// bits of a byte; cut > 0: cs_n goes high after that many bits
task send_byte(input [7:0] b, input integer cut);
	integer k;
	begin
		for (k = 7; k >= 0; k = k - 1) begin
			if (cut != 0 && 8 - k > cut) k = -1;
			else begin
				mosi = b[k];
				#(half);
				sck = 1'b1;
				#(half);
				sck = 1'b0;
			end
		end
		compare;
	end
endtask

integer i, j, n, cut;
reg [31:0] r;
initial begin
	#200;
	for (i = 0; i < BURSTS; i = i + 1) begin
		r = $random(seed);
		half = 14 + r[5:0] % 37; // 14..50 ns
		n = r[13:8] % 41;
		cut = (r[19:16] == 0) ? 1 + r[22:20] % 7 : 0;
		cs_n = 1'b0;
		#(20 + r[27:24] * 5);
		for (j = 0; j < 5 + n; j = j + 1)
			send_byte($random(seed), (cut != 0 && j == 5 + n - 1) ? cut : 0);
		#(10 + r[31:28] * 7);
		cs_n = 1'b1;
		#(50 + ($random(seed) & 255));
	end
	#500;
	$display("tb_eq_burst_rx: %0d writes, %0d checks", writes, checks);
	$display("tb_eq_burst_rx: %0d errors", errors);
	$finish;
end

endmodule
