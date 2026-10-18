`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_spi_slave.v

 SPI slave, mode 0 (CPOL 0, CPHA 0), MSB first, N-bit words: the Verilog port of spi_slave.vhd
 (Jonny Doin's spi_slave, as karabas-go-core-nanomig uses it) without its debug ports and the
 other SPI modes, which no karabas core uses.

 The shift register and its state machine run on sck (the burst link shifts at 32 MHz with clk
 near 28 MHz, so sck cannot be oversampled): bits are taken on the rising and shifted on the
 falling sck edge, a low ssel puts the state machine in its idle state. A received word goes to
 the clk domain by a flag that the clk side sees through a 4-stage chain: do_valid is one clock,
 dout holds the word until the next one.

 Transmit: di is taken into its register on each clock with wren; the shifter loads it with the
 first bit of a word (from idle) and after the last bit of the previous word. di_req asks for
 the next word during the last PREFETCH+2 bits of a word, a clock long, through the same chain.
 karabas: no request in idle (spi_slave.vhd had one): the shifter follows sck also while the
 slave is not selected (bursts on their own chip select, a spike on ssel), and a request there
 took a reply word that never went out.
*/

module kg_spi_slave #(
	parameter N = 32,       // word length, >= 8
	parameter PREFETCH = 2  // di_req lookahead, <= N - 5
) (
	input wire clk,
	input wire sck,
	input wire ssel,        // low active
	input wire mosi,
	output wire miso,

	input wire [N-1:0] di,
	input wire wren,
	output reg di_req = 1'b0,

	output reg do_valid = 1'b0,
	output wire [N-1:0] dout
);

// bits of the state, N+1..0
function integer state_bits(input integer n);
	begin
		state_bits = 1;
		while ((1 << state_bits) <= n + 1)
			state_bits = state_bits + 1;
	end
endfunction
localparam SW = state_bits(N);

// ---------------- sck domain ----------------

reg rx_bit = 1'b0;
always @(posedge sck)
	rx_bit <= mosi;

reg [SW-1:0] state = 0;
reg [N-1:0] sh = {N{1'b0}};
reg [N-1:0] do_buffer = {N{1'b0}};
reg do_transfer = 1'b0;
reg wren_ack = 1'b0;

reg [N-1:0] di_reg = {N{1'b0}};
reg wren_r = 1'b0;

// states: N+1 unused, N..2 shift (a request for the next word in PREFETCH+2..1), 1 the last bit
// (the word to dout, the next one into the shifter), 0 idle (the shifter loads with the first bit)
wire shifting = state >= 2 && state <= N;
wire last = state == 1;
wire idle = state == 0;
wire req = state >= 1 && state <= PREFETCH + 2;

wire [SW-1:0] state_next = last ? N : idle ? N - 1 : (state > N) ? 0 : state - 1'b1;
wire [N-1:0] sh_next = shifting ? { sh[N-2:0], rx_bit } :
                       last ? (wren_r ? di_reg : {N{1'b0}}) :
                       idle ? { di_reg[N-2:0], rx_bit } : sh;
wire do_transfer_next = last | (do_transfer & ~idle & ~(state >= PREFETCH + 3 && state <= N));
wire wren_ack_next = idle | (last & wren_r);

assign miso = idle ? di_reg[N-1] : sh[N-1];

always @(negedge sck or posedge ssel)
	if (ssel)
		state <= 0;
	else
		state <= state_next;

always @(negedge sck) begin
	sh <= sh_next;
	if (last)
		do_buffer <= { sh[N-2:0], rx_bit };
	do_transfer <= do_transfer_next;
	wren_ack <= wren_ack_next;
end

assign dout = do_buffer;

// ---------------- clk domain ----------------

reg [3:0] valid_s = 4'd0, req_s = 4'd0; // A, B, C, D of spi_slave.vhd
always @(posedge clk) begin
	valid_s <= { valid_s[2:0], do_transfer };
	req_s <= { req_s[2:0], req };
	do_valid <= valid_s[0] & valid_s[1] & ~valid_s[3];
	di_req <= req_s[0] & req_s[1] & ~req_s[3];

	if (wren)
		di_reg <= di;
	if (wren)
		wren_r <= 1'b1;
	else if (wren_ack)
		wren_r <= 1'b0;
end

endmodule
