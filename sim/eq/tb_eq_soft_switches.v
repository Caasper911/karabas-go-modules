`timescale 1ns / 1ps

// The soft_switches.vhd of tsconf (sim/eq/ref) against kg_soft_switches.v with the fields cut out
// as the core would: random commands (also repeated ones, which are not taken again, and indexes
// past the registers); every output compared after every clock, upd counted against the model.
// Ends with "tb_eq_soft_switches: N errors".

module tb_eq_soft_switches;

parameter N = 50000;
`include "eq_check.vh"

reg clk = 1'b0;
always #10 clk = ~clk;

reg [15:0] cmd = 16'h0000;
wire covox, psg_type, vga60, pause, reset_gs, nmi, reset;
wire [1:0] psg_mix;
wire [2:0] joy_l, joy_r;

soft_switches old_dut(.CLK(clk), .SOFTSW_COMMAND(cmd), .COVOX_EN(covox), .PSG_MIX(psg_mix), .PSG_TYPE(psg_type),
	.JOY_TYPE_L(joy_l), .JOY_TYPE_R(joy_r), .VGA_60HZ(vga60), .PAUSE(pause), .RESET_GS(reset_gs), .NMI(nmi), .RESET(reset));

wire [10*8-1:0] regs;
wire upd;
kg_soft_switches #(.N(10)) new_dut(.clk(clk), .command(cmd), .regs(regs), .upd(upd));

always @(negedge clk) begin
	eq_check("COVOX_EN", covox, regs[0*8]);
	eq_check("PSG_MIX", psg_mix, regs[1*8 +: 2]);
	eq_check("PSG_TYPE", psg_type, regs[2*8]);
	eq_check("JOY_TYPE_L", joy_l, regs[3*8 +: 3]);
	eq_check("JOY_TYPE_R", joy_r, regs[4*8 +: 3]);
	eq_check("VGA_60HZ", vga60, regs[5*8]);
	eq_check("PAUSE", pause, regs[6*8]);
	eq_check("RESET_GS", reset_gs, regs[7*8]);
	eq_check("NMI", nmi, regs[8*8]);
	eq_check("RESET", reset, regs[9*8]);
end

// upd: one clock for each new command to a register index below 10
reg [15:0] prev = 16'hFFFF;
reg exp_upd = 1'b0;
always @(posedge clk) begin
	exp_upd <= cmd != prev && cmd[15:8] < 10;
	prev <= cmd;
end
always @(negedge clk) eq_check("upd", exp_upd, upd);

integer seed = 23;
reg [31:0] r;
reg [7:0] idx;
always @(negedge clk) begin
	r = $random(seed);
	idx = r[11:8] % 12; // 0..11
	if (r[1:0] == 0)
		cmd <= { idx, r[23:16] };
end

initial begin
	repeat (N) @(posedge clk);
	$display("tb_eq_soft_switches: %0d checks", checks);
	$display("tb_eq_soft_switches: %0d errors", errors);
	$finish;
end

endmodule
