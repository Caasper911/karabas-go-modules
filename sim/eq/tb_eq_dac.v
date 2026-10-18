`timescale 1ns / 1ps

// dac.vhd against kg_sigma_delta_dac.v (MSBI 15): random samples held for random times, a reset
// now and then; dout compared after every clock. Ends with "tb_eq_dac: N errors".

module tb_eq_dac;

parameter N = 200000;
`include "eq_check.vh"

reg clk = 1'b0;
always #10 clk = ~clk;

reg reset = 1'b1;
reg [15:0] d = 16'd0;
wire old_q, new_q;

dac old_dut(.I_CLK(clk), .I_RESET(reset), .I_DATA(d), .O_DAC(old_q));
kg_sigma_delta_dac #(.MSBI(15)) new_dut(.clk(clk), .reset(reset), .din(d), .dout(new_q));

integer seed = 11, hold = 0, i;
reg [31:0] r;
always @(negedge clk) begin
	r = $random(seed);
	reset <= (r[11:0] == 0);
	if (hold == 0) begin
		d <= (r[13:12] == 0) ? 16'h0000 : (r[13:12] == 1) ? 16'hFFFF : $random(seed);
		hold = r[23:16];
	end
	else
		hold = hold - 1;
end

reg started = 1'b0;
always @(negedge clk) if (started) eq_check("O_DAC", old_q, new_q);

initial begin
	repeat (3) @(negedge clk);
	reset = 1'b0;
	started = 1'b1;
	repeat (N) @(posedge clk);
	$display("tb_eq_dac: %0d checks", checks);
	$display("tb_eq_dac: %0d errors", errors);
	$finish;
end

endmodule
