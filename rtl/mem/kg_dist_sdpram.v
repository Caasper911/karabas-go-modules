`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_dist_sdpram.v

 Simple dual port distributed (LUT) RAM, inferred (replaces simple_dual_port_ram of coregen
 dist_mem_gen): one write port (a, d, we on clk) and one asynchronous read port (dpra -> dpo),
 plus the asynchronous read of the write address (spo). No read clock: the data follow the address
 in the same clock. INIT_FILE: $readmemh file, "" = zeros.
*/

module kg_dist_sdpram #(
	parameter DW = 8,
	parameter AW = 6,
	parameter INIT_FILE = ""
) (
	input wire clk,
	input wire we,
	input wire [AW-1:0] a,
	input wire [DW-1:0] d,
	output wire [DW-1:0] spo,

	input wire [AW-1:0] dpra,
	output wire [DW-1:0] dpo
);

reg [DW-1:0] mem [0:(1<<AW)-1];

// XST starts the block RAM and its output latch at 0 without an INIT_FILE; the simulation as well
// (the loop is hidden from XST, which limits loop iterations)
integer i;
initial begin
	if (INIT_FILE != "")
		$readmemh(INIT_FILE, mem);
	// synthesis translate_off
	else
		for (i = 0; i < (1<<AW); i = i + 1)
			mem[i] = {DW{1'b0}};
	// synthesis translate_on
end

always @(posedge clk) begin
	if (we)
		mem[a] <= d;
end

assign spo = mem[a];
assign dpo = mem[dpra];

endmodule
