`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_spram.v

 Single port block RAM, inferred (replaces the Single_Port_RAM cores of coregen blk_mem_gen).
 One clock of read latency, no output register, like blk_mem_gen with the output registers off.
 WRITE_FIRST = 1: a write shows the new word on dout (blk_mem_gen WRITE_FIRST, the default of
 most of the karabas cores); 0: the old word (READ_FIRST). en = 0 holds dout and blocks the write.
 INIT_FILE: $readmemh file, "" = zeros (tools/coe2hex.py converts a .coe).
*/

module kg_spram #(
	parameter DW = 8,
	parameter AW = 10,
	parameter WRITE_FIRST = 1,
	parameter INIT_FILE = ""
) (
	input wire clk,
	input wire en,
	input wire we,
	input wire [AW-1:0] addr,
	input wire [DW-1:0] din,
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
	if (en) begin
		if (we) begin
			mem[addr] <= din;
			dout <= WRITE_FIRST ? din : mem[addr];
		end
		else
			dout <= mem[addr];
	end
end

endmodule
