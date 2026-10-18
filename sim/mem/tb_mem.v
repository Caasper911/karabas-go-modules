`timescale 1ns / 1ps

// The memories of rtl/mem against a model in this testbench: random stimulus, every output
// checked after every clock edge.
// - kg_spram (write-first and read-first), kg_sprom (INIT_FILE rom.hex), kg_sdpram,
//   kg_tdpram (WE_W 1 and 4, two clocks), kg_dist_sdpram, kg_dist_spram (DEPTH below 2^AW);
// - dpram (both ports on one clock, write-first);
// - fifo (the queue to the mcu in mcu.vhd: dout registered on rd, full one entry early).
// A port of a dual port memory reading the address the other port writes at the same edge:
// the block RAM gives an undefined word (collision); not checked for dpram, whose ports share a
// clock. The kg_* memories on two clocks give the old word in simulation, as the model.
// iverilog and ISim. Ends with "tb_mem: N errors".
// `define VHDL_MODELS: dpram and fifo are the VHDL models of sim/mcu (dpram_sim.vhd,
// fifo_sim.vhd, which the ISim runs of mcu.vhd use in their place); fifo_sim has no data_count.

module tb_mem;

parameter N = 20000; // clocks of random stimulus

reg clka = 1'b0, clkb = 1'b0;
always #5 clka = ~clka;
always #7 clkb = ~clkb;

integer errors = 0;
integer checks = 0;
integer seed = 1;

task check(input [255:0] name, input [31:0] got, input [31:0] exp);
	begin
		checks = checks + 1;
		if (^exp !== 1'bx && got !== exp) begin
			if (errors < 20) $display("%t ERROR: %0s %h, expected %h", $time, name, got, exp);
			errors = errors + 1;
		end
	end
endtask

// ---------------- stimulus ----------------

reg [31:0] ra, rb;
// changed after the checks of the same edge read them (the asynchronous reads are checked too)
always @(negedge clka) ra <= $random(seed);
always @(negedge clkb) rb <= $random(seed);

// ---------------- kg_spram ----------------

wire [7:0] spw_q, spr_q;
reg [7:0] sp_mem [0:255];
reg [7:0] spw_exp = 8'd0, spr_exp = 8'd0;
wire sp_en = ra[0] | ra[1];
wire sp_we = ra[2] & ra[3];
wire [7:0] sp_a = ra[15:8];
wire [7:0] sp_d = ra[23:16];

// the same stimulus to both: one memory content
kg_spram #(.DW(8), .AW(8), .WRITE_FIRST(1)) u_spw(.clk(clka), .en(sp_en), .we(sp_we), .addr(sp_a), .din(sp_d), .dout(spw_q));
kg_spram #(.DW(8), .AW(8), .WRITE_FIRST(0)) u_spr(.clk(clka), .en(sp_en), .we(sp_we), .addr(sp_a), .din(sp_d), .dout(spr_q));

always @(posedge clka)
	if (sp_en) begin
		if (sp_we) sp_mem[sp_a] <= sp_d;
		spw_exp <= sp_we ? sp_d : sp_mem[sp_a];
		spr_exp <= sp_mem[sp_a];
	end

// ---------------- kg_sprom (rom.hex: word i = i * 37 + 5) ----------------

wire [11:0] rom_q;
reg [11:0] rom_exp = 12'd0;
kg_sprom #(.DW(12), .AW(9), .INIT_FILE("rom.hex")) u_rom(.clk(clka), .en(ra[4]), .addr(ra[24:16]), .dout(rom_q));
always @(posedge clka)
	if (ra[4]) rom_exp <= (ra[24:16] * 37 + 5) & 12'hFFF;

// ---------------- kg_sdpram: write on clka, read on clkb ----------------

wire [15:0] sdp_q;
reg [15:0] sdp_mem [0:1023];
reg [15:0] sdp_exp = 16'd0;
kg_sdpram #(.DW(16), .AW(10)) u_sdp(
	.clka(clka), .wea(ra[5]), .addra(ra[9:0]), .dina(ra[31:16]),
	.clkb(clkb), .enb(rb[5]), .addrb(rb[9:0]), .doutb(sdp_q)
);
always @(posedge clka) if (ra[5]) sdp_mem[ra[9:0]] <= ra[31:16];
always @(posedge clkb) if (rb[5]) sdp_exp <= sdp_mem[rb[9:0]];

// ---------------- kg_tdpram, WE_W = 1 and 4 ----------------
// small address range (16 words), so the ports often meet; never both writing one address

wire [7:0] td1_qa, td1_qb;
reg [7:0] td1_mem [0:15];
reg [7:0] td1_ea = 8'd0, td1_eb = 8'd0;
wire td1_wa = ra[6];
wire td1_wb = rb[6] && !(ra[6] && ra[3:0] == rb[3:0]);
kg_tdpram #(.DW(8), .AW(4), .WRITE_FIRST(1)) u_td1(
	.clka(clka), .ena(ra[7]), .wea(td1_wa), .addra(ra[3:0]), .dina(ra[15:8]), .douta(td1_qa),
	.clkb(clkb), .enb(rb[7]), .web(td1_wb), .addrb(rb[3:0]), .dinb(rb[15:8]), .doutb(td1_qb)
);
always @(posedge clka)
	if (ra[7]) begin
		if (td1_wa) td1_mem[ra[3:0]] <= ra[15:8];
		td1_ea <= td1_wa ? ra[15:8] : td1_mem[ra[3:0]];
	end
always @(posedge clkb)
	if (rb[7]) begin
		if (td1_wb) td1_mem[rb[3:0]] <= rb[15:8];
		td1_eb <= td1_wb ? rb[15:8] : td1_mem[rb[3:0]];
	end

// byte lanes, read-first
wire [31:0] td4_qa, td4_qb;
reg [31:0] td4_mem [0:15];
reg [31:0] td4_ea = 32'd0, td4_eb = 32'd0;
wire [3:0] td4_wa = ra[11:8] & {4{ra[12]}};
wire [3:0] td4_wb = rb[11:8] & {4{rb[12]}} & ~((ra[3:0] == rb[3:0]) ? td4_wa : 4'b0000);
wire [31:0] td4_da = { ra[7:0], ra[31:24], ra[15:8], ra[23:16] };
wire [31:0] td4_db = { rb[7:0], rb[31:24], rb[15:8], rb[23:16] };
kg_tdpram #(.DW(32), .AW(4), .WE_W(4), .WRITE_FIRST(0)) u_td4(
	.clka(clka), .ena(ra[13]), .wea(td4_wa), .addra(ra[3:0]), .dina(td4_da), .douta(td4_qa),
	.clkb(clkb), .enb(rb[13]), .web(td4_wb), .addrb(rb[3:0]), .dinb(td4_db), .doutb(td4_qb)
);
integer l;
always @(posedge clka)
	if (ra[13]) begin
		for (l = 0; l < 4; l = l + 1)
			if (td4_wa[l]) td4_mem[ra[3:0]][l*8 +: 8] <= td4_da[l*8 +: 8];
		td4_ea <= td4_mem[ra[3:0]];
	end
integer m;
always @(posedge clkb)
	if (rb[13]) begin
		for (m = 0; m < 4; m = m + 1)
			if (td4_wb[m]) td4_mem[rb[3:0]][m*8 +: 8] <= td4_db[m*8 +: 8];
		td4_eb <= td4_mem[rb[3:0]];
	end

// ---------------- kg_dist_sdpram, kg_dist_spram: asynchronous read ----------------

wire [5:0] dsd_spo, dsd_dpo;
reg [5:0] dsd_mem [0:63];
kg_dist_sdpram #(.DW(6), .AW(6)) u_dsd(
	.clk(clka), .we(ra[14]), .a(ra[21:16]), .d(ra[29:24]), .spo(dsd_spo), .dpra(ra[27:22]), .dpo(dsd_dpo)
);
always @(posedge clka) if (ra[14]) dsd_mem[ra[21:16]] <= ra[29:24];

wire [8:0] dsp_spo;
reg [8:0] dsp_mem [0:319];
wire [8:0] dsp_a = ra[24:16] % 320;
kg_dist_spram #(.DW(9), .AW(9), .DEPTH(320)) u_dsp(.clk(clka), .we(ra[15]), .a(dsp_a), .d(ra[8:0]), .spo(dsp_spo));
always @(posedge clka) if (ra[15]) dsp_mem[dsp_a] <= ra[8:0];

// ---------------- dpram ----------------

wire [7:0] dp_qa, dp_qb;
reg [7:0] dp_mem [0:255];
reg [7:0] dp_ea = 8'd0, dp_eb = 8'd0;
wire dp_wa = ra[16];
wire dp_wb = ra[17] && !(dp_wa && ra[7:0] == ra[31:24]);
dpram #(.DATAWIDTH(8), .ADDRWIDTH(8)) u_dp(
	.clock(clka),
	.address_a(ra[7:0]), .data_a(ra[15:8]), .wren_a(dp_wa), .q_a(dp_qa),
	.address_b(ra[31:24]), .data_b(ra[23:16]), .wren_b(dp_wb), .q_b(dp_qb)
);
always @(posedge clka) begin
	if (dp_wa) dp_mem[ra[7:0]] <= ra[15:8];
	if (dp_wb) dp_mem[ra[31:24]] <= ra[23:16];
	// X: a read of the address the other port writes, not checked
	dp_ea <= dp_wa ? ra[15:8] : (dp_wb && ra[7:0] == ra[31:24]) ? 8'bx : dp_mem[ra[7:0]];
	dp_eb <= dp_wb ? ra[23:16] : (dp_wa && ra[7:0] == ra[31:24]) ? 8'bx : dp_mem[ra[31:24]];
end

// ---------------- fifo ----------------
// phases of mostly writes and mostly reads, so it runs full and empty

reg fifo_rst = 1'b1;
wire [11:0] ff_dout;
wire ff_full, ff_empty;
wire [3:0] ff_count;
reg [11:0] ff_q [0:15];
integer ff_n = 0, ff_rp = 0, ff_wp = 0;
reg [11:0] ff_exp;
wire [9:0] phase = checks / 2000;
wire ff_wr = phase[0] ? (ra[19:18] == 2'b00) : (ra[19:18] != 2'b00);
wire ff_rd = phase[0] ? (ra[21:20] != 2'b00) : (ra[21:20] == 2'b00);
fifo #(.DATA_WIDTH(12), .ADDR_WIDTH(4)) u_ff(
	.clk(clka), .reset(fifo_rst), .rd(ff_rd), .wr(ff_wr), .din(ra[31:20]),
	.dout(ff_dout), .full(ff_full), .empty(ff_empty)
`ifndef VHDL_MODELS
	, .data_count(ff_count)
`endif
);
integer ff_n0;
always @(posedge clka)
	if (!fifo_rst) begin
		// full and empty of the count before this clock decide, as in the fifo
		ff_n0 = ff_n;
		if (ff_rd && ff_n0 > 0) begin
			ff_exp <= ff_q[ff_rp];
			ff_rp = (ff_rp + 1) % 16;
			ff_n = ff_n - 1;
		end
		if (ff_wr && ff_n0 < 15) begin
			ff_q[ff_wp] = ra[31:20];
			ff_wp = (ff_wp + 1) % 16;
			ff_n = ff_n + 1;
		end
	end

// ---------------- checks ----------------

reg started = 1'b0;
always @(negedge clka) if (started) begin
	check("kg_spram write-first", spw_q, spw_exp);
	check("kg_spram read-first", spr_q, spr_exp);
	check("kg_sprom", rom_q, rom_exp);
	check("kg_tdpram 1 port a", td1_qa, td1_ea);
	check("kg_tdpram 4 port a", td4_qa, td4_ea);
	check("kg_dist_sdpram spo", dsd_spo, dsd_mem[ra[21:16]]);
	check("kg_dist_sdpram dpo", dsd_dpo, dsd_mem[ra[27:22]]);
	check("kg_dist_spram spo", dsp_spo, dsp_mem[dsp_a]);
	check("dpram port a", dp_qa, dp_ea);
	check("dpram port b", dp_qb, dp_eb);
	if (!fifo_rst) begin
		check("fifo empty", ff_empty, ff_n == 0);
		check("fifo full", ff_full, ff_n == 15);
`ifndef VHDL_MODELS
		check("fifo data_count", ff_count, ff_n);
`endif
		check("fifo dout", ff_dout, ff_exp);
	end
end
always @(negedge clkb) if (started) begin
	check("kg_sdpram", sdp_q, sdp_exp);
	check("kg_tdpram 1 port b", td1_qb, td1_eb);
	check("kg_tdpram 4 port b", td4_qb, td4_eb);
end

// the memories start at 0 in simulation (XST starts the block RAMs at 0); dpram has no
// such loop, it starts unknown: fill the model and the memory through port a first
integer i;
initial begin
	for (i = 0; i < 256; i = i + 1) begin sp_mem[i] = 0; dp_mem[i] = 0; end
	for (i = 0; i < 1024; i = i + 1) sdp_mem[i] = 0;
	for (i = 0; i < 16; i = i + 1) begin td1_mem[i] = 0; td4_mem[i] = 0; end
	for (i = 0; i < 64; i = i + 1) dsd_mem[i] = 0;
	for (i = 0; i < 320; i = i + 1) dsp_mem[i] = 0;
	ff_exp = 12'bx;
`ifndef VHDL_MODELS
	for (i = 0; i < 256; i = i + 1) u_dp.mem[i] = 0;
`endif
	repeat (3) @(negedge clka);
	fifo_rst = 1'b0;
	started = 1'b1;
	repeat (N) @(posedge clka);
	$display("tb_mem: %0d checks", checks);
	$display("tb_mem: %0d errors", errors);
	$finish;
end

endmodule
