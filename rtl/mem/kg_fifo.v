`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_fifo.v

 Synchronous FIFO of 2^AW words, the replacement of fifo.v (whose last entry was never used and
 whose data_count saturated). rd takes the oldest word into dout in the next clock (dout holds
 it until the next rd, as a block RAM output register); rd while empty and wr while full do
 nothing, also with an rd in the same clock (its address is the one read: a collision of the
 block RAM ports). reset empties it.
 XST: 24 x 512 takes one RAMB16 and 41 LUTs (fifo.v: 87), 8 x 16 and 8 x 64 LUT RAM.
*/

module kg_fifo #(
	parameter DW = 8,
	parameter AW = 8
) (
	input wire clk,
	input wire reset,

	input wire wr,
	input wire [DW-1:0] din,
	output wire full,

	input wire rd,
	output reg [DW-1:0] dout = {DW{1'b0}},
	output wire empty,

	output reg [AW:0] count = {(AW+1){1'b0}}
);

reg [DW-1:0] mem [0:(1<<AW)-1];
reg [AW-1:0] rp = {AW{1'b0}}, wp = {AW{1'b0}};

assign empty = count == 0;
assign full = count[AW];

wire do_rd = rd && !empty;
wire do_wr = wr && !full;

always @(posedge clk) begin
	if (do_wr)
		mem[wp] <= din;
	if (do_rd)
		dout <= mem[rp];
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		rp <= {AW{1'b0}};
		wp <= {AW{1'b0}};
		count <= {(AW+1){1'b0}};
	end
	else begin
		if (do_wr)
			wp <= wp + 1'b1;
		if (do_rd)
			rp <= rp + 1'b1;
		if (do_wr && !do_rd)
			count <= count + 1'b1;
		else if (do_rd && !do_wr)
			count <= count - 1'b1;
	end
end

endmodule
