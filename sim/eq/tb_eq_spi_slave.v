`timescale 1ns / 1ps

// spi_slave.vhd against kg_spi_slave.v (N 24, as mcu.vhd), ISim (ghdl rejects spi_slave.vhd):
// random frames with random sck rates and reply words (wren now and then), sck running while the
// slave is not selected (bursts), short spikes on ssel; do_valid, dout and di_req compared after
// every clock, miso after every clock and every sck edge. Ends with "tb_eq_spi_slave: N errors".

module tb_eq_spi_slave;

parameter FRAMES = 1500;
`include "eq_check.vh"

reg clk = 1'b0;
always #17.65 clk = ~clk;

reg sck = 1'b0, mosi = 1'b0, ssel = 1'b1, wren = 1'b0;
reg [23:0] di = 24'd0;
wire old_miso, new_miso, old_valid, new_valid, old_req, new_req;
wire [23:0] old_do, new_do;

spi_slave #(.N(24)) old_dut(
	.clk_i(clk), .spi_ssel_i(ssel), .spi_sck_i(sck), .spi_mosi_i(mosi), .spi_miso_o(old_miso),
	.di_req_o(old_req), .di_i(di), .wren_i(wren), .do_valid_o(old_valid), .do_o(old_do),
	.do_transfer_o(), .wren_o(), .wren_ack_o(), .rx_bit_reg_o(), .state_dbg_o()
);
kg_spi_slave #(.N(24)) new_dut(
	.clk(clk), .sck(sck), .ssel(ssel), .mosi(mosi), .miso(new_miso),
	.di(di), .wren(wren), .di_req(new_req), .do_valid(new_valid), .dout(new_do)
);

always @(negedge clk) begin
	eq_check("miso", old_miso, new_miso);
	eq_check("do_valid_o", old_valid, new_valid);
	eq_check("do_o", old_do, new_do);
	eq_check("di_req_o", old_req, new_req);
end
always @(sck) #1 eq_check("miso (sck)", old_miso, new_miso);

integer seed = 13, half = 31, valids = 0;
always @(posedge clk) if (old_valid) valids = valids + 1;

// the reply side, in phases of 100 frames: wren mostly held (as mcu.vhd, which ties it to 1),
// or one clock with each new word now and then (then the shifter sends zeros without one)
integer i;
reg [31:0] rw;
always @(negedge clk) begin
	rw = $random(seed);
	if (rw[3:0] == 0) di <= $random(seed);
	if ((i / 100) % 2 == 0)
		wren <= rw[7:4] != 0;
	else
		wren <= rw[3:0] == 0 && rw[8];
end

task bits(input integer n);
	integer k;
	begin
		for (k = 0; k < n; k = k + 1) begin
			mosi = $random(seed);
			#(half);
			sck = 1'b1;
			#(half);
			sck = 1'b0;
		end
	end
endtask

// a spike on ssel during the next bits
reg spike_go = 1'b0;
always @(posedge spike_go) begin
	#(half * 3);
	ssel = 1'b0;
	#110;
	ssel = 1'b1;
end

reg [31:0] r;
initial begin
	#200;
	for (i = 0; i < FRAMES; i = i + 1) begin
		r = $random(seed);
		half = 20 + r[5:0] % 40;
		case (r[9:8])
		2'd0, 2'd1: begin // a frame of 1 to 3 words
			ssel = 1'b0;
			#(50 + r[15:12] * 10);
			bits(24 * (1 + r[17:16] % 3));
			#(30 + r[23:20] * 5);
			ssel = 1'b1;
		end
		2'd2: begin // a frame cut short
			ssel = 1'b0;
			#100;
			bits(1 + r[20:16] % 23);
			#50;
			ssel = 1'b1;
		end
		2'd3: begin // sck without ssel (a burst), maybe with a spike, then a pause
			spike_go = r[12];
			bits(8 + r[19:16]);
			spike_go = 1'b0;
			#(200 + r[23:20] * 20);
		end
		endcase
		#(100 + r[31:24] * 4);
	end
	#1000;
	$display("tb_eq_spi_slave: %0d words, %0d checks", valids, checks);
	$display("tb_eq_spi_slave: %0d errors", errors);
	$finish;
end

endmodule
