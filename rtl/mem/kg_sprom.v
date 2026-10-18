`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_sprom.v

 Block ROM, inferred (replaces the Single_Port_ROM cores of coregen blk_mem_gen). One clock of
 read latency. INIT_FILE: $readmemh file (tools/coe2hex.py converts a .coe).
*/

module kg_sprom #(
	parameter DW = 8,
	parameter AW = 10,
	parameter INIT_FILE = ""
) (
	input wire clk,
	input wire en,
	input wire [AW-1:0] addr,
	output reg [DW-1:0] dout
);

reg [DW-1:0] mem [0:(1<<AW)-1];

// XST starts the block RAM and its output latch at 0 without an INIT_FILE; the simulation as well
// (the loop is hidden from XST, which limits loop iterations)
integer i;
initial begin
	dout = {DW{1'b0}};
	if (INIT_FILE != "")
		$readmemh(INIT_FILE, mem);
	// synthesis translate_off
	else
		for (i = 0; i < (1<<AW); i = i + 1)
			mem[i] = {DW{1'b0}};
	// synthesis translate_on
end

always @(posedge clk) begin
	if (en)
		dout <= mem[addr];
end

endmodule
