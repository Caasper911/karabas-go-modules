`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_tdpram.v

 True dual port block RAM, inferred (replaces the True_Dual_Port_RAM cores of coregen
 blk_mem_gen with the same width on both ports): two read / write ports, each on its own clock.
 One clock of read latency per port. WRITE_FIRST = 1: a port that writes shows the new word on its
 dout, 0: the old word. Both ports writing the same address at once is undefined, as in the
 primitive. en = 0 holds dout and blocks the write.
 WE_W > 1: byte (lane) write enables, we[n] writes bits [(n+1)*DW/WE_W-1 : n*DW/WE_W]
 (blk_mem_gen use_byte_write_enable, e.g. 4 for 32 bits); a write shows the new lanes and the old
 ones on dout. Each lane is a memory of its own, which takes the same block RAMs for lanes of
 8 bits or more.
 INIT_FILE: $readmemh file, "" = zeros; only with WE_W = 1.
*/

module kg_tdpram #(
	parameter DW = 8,
	parameter AW = 10,
	parameter WE_W = 1,
	parameter WRITE_FIRST = 1,
	parameter INIT_FILE = ""
) (
	input wire clka,
	input wire ena,
	input wire [WE_W-1:0] wea,
	input wire [AW-1:0] addra,
	input wire [DW-1:0] dina,
	output wire [DW-1:0] douta,

	input wire clkb,
	input wire enb,
	input wire [WE_W-1:0] web,
	input wire [AW-1:0] addrb,
	input wire [DW-1:0] dinb,
	output wire [DW-1:0] doutb
);

localparam LW = DW / WE_W;

genvar l;
generate
	for (l = 0; l < WE_W; l = l + 1) begin : kg_tdpram_lane

		reg [LW-1:0] mem [0:(1<<AW)-1];
		reg [LW-1:0] qa, qb;
		assign douta[l*LW +: LW] = qa;
		assign doutb[l*LW +: LW] = qb;

		// XST starts the block RAM and its output latch at 0 without an INIT_FILE; the simulation as well
		// (the loop is hidden from XST, which limits loop iterations)
		integer i;
		initial begin
			qa = {LW{1'b0}};
			qb = {LW{1'b0}};
			if (INIT_FILE != "")
				$readmemh(INIT_FILE, mem);
			// synthesis translate_off
			else
				for (i = 0; i < (1<<AW); i = i + 1)
					mem[i] = {LW{1'b0}};
			// synthesis translate_on
		end

		always @(posedge clka) begin
			if (ena) begin
				if (wea[l]) begin
					mem[addra] <= dina[l*LW +: LW];
					qa <= WRITE_FIRST ? dina[l*LW +: LW] : mem[addra];
				end
				else
					qa <= mem[addra];
			end
		end

		always @(posedge clkb) begin
			if (enb) begin
				if (web[l]) begin
					mem[addrb] <= dinb[l*LW +: LW];
					qb <= WRITE_FIRST ? dinb[l*LW +: LW] : mem[addrb];
				end
				else
					qb <= mem[addrb];
			end
		end

	end
endgenerate

endmodule
