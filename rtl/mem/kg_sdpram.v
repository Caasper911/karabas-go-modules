`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_sdpram.v

 Simple dual port block RAM, inferred (replaces the Simple_Dual_Port_RAM cores of coregen
 blk_mem_gen): port A writes, port B reads, each on its own clock (tie them together for one
 clock domain). One clock of read latency on B. A read of the word being written in the same clock
 gives the old word on one clock and is undefined across clocks, as in blk_mem_gen.
 enb = 0 holds doutb (blk_mem_gen Use_ENB_Pin). INIT_FILE: $readmemh file, "" = zeros.
*/

module kg_sdpram #(
	parameter DW = 8,
	parameter AW = 10,
	parameter INIT_FILE = ""
) (
	input wire clka,
	input wire wea,
	input wire [AW-1:0] addra,
	input wire [DW-1:0] dina,

	input wire clkb,
	input wire enb,
	input wire [AW-1:0] addrb,
	output reg [DW-1:0] doutb
);

reg [DW-1:0] mem [0:(1<<AW)-1];

// XST starts the block RAM and its output latch at 0 without an INIT_FILE; the simulation as well
// (the loop is hidden from XST, which limits loop iterations)
integer i;
initial begin
	doutb = {DW{1'b0}};
	if (INIT_FILE != "")
		$readmemh(INIT_FILE, mem);
	// synthesis translate_off
	else
		for (i = 0; i < (1<<AW); i = i + 1)
			mem[i] = {DW{1'b0}};
	// synthesis translate_on
end

always @(posedge clka) begin
	if (wea)
		mem[addra] <= dina;
end

always @(posedge clkb) begin
	if (enb)
		doutb <= mem[addrb];
end

endmodule
