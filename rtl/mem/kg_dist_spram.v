`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_dist_spram.v

 Single port distributed (LUT) RAM, inferred (replaces single_port_ram of coregen dist_mem_gen):
 synchronous write, asynchronous read (spo follows a in the same clock). DEPTH may be less than
 2^AW (dist_mem_gen allows any depth, e.g. 320). INIT_FILE: $readmemh file, "" = zeros.
*/

module kg_dist_spram #(
	parameter DW = 8,
	parameter AW = 6,
	parameter DEPTH = (1<<AW),
	parameter INIT_FILE = ""
) (
	input wire clk,
	input wire we,
	input wire [AW-1:0] a,
	input wire [DW-1:0] d,
	output wire [DW-1:0] spo
);

reg [DW-1:0] mem [0:DEPTH-1];

// XST starts the block RAM and its output latch at 0 without an INIT_FILE; the simulation as well
// (the loop is hidden from XST, which limits loop iterations)
integer i;
initial begin
	if (INIT_FILE != "")
		$readmemh(INIT_FILE, mem);
	// synthesis translate_off
	else
		for (i = 0; i < DEPTH; i = i + 1)
			mem[i] = {DW{1'b0}};
	// synthesis translate_on
end

always @(posedge clk) begin
	if (we)
		mem[a] <= d;
end

assign spo = mem[a];

endmodule
