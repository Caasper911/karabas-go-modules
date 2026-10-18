`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_burst_rx.v

 MCU -> FPGA burst receiver (karabas-go-firmware docs/burst_protocol.md), the Verilog port of
 burst_rx.vhd. While cs_n is low the mcu sends (SPI mode 0, MSB first):
   TYPE, ADDR[31:24], ADDR[23:16], ADDR[15:8], ADDR[7:0], D0, D1, ... Dn-1
 For every data byte Dk: addr = ADDR + k, data = Dk and one clock of wr. A new burst starts with
 a new header after cs_n went high.

 The shift register runs on sck; a completed byte goes to the clk domain with a toggle
 synchroniser. The byte register holds for the next 8 sck periods, so clk must see the toggle
 within that time: 8 / f_sck > 5 / f_clk (clk 28 MHz: sck up to ~40 MHz; announce less in the
 CMD_CAPS answer for margin).
*/

module kg_burst_rx (
	input wire clk,
	input wire sck,         // shared with the classic link
	input wire mosi,
	// the burst chip select: resets the bit counter at once, enables the shift register on sck
	/* verilator lint_off SYNCASYNCNET */
	input wire cs_n,
	/* verilator lint_on SYNCASYNCNET */
	output wire [7:0] btype, // type of the current burst (the target)
	output reg [31:0] addr = 32'd0,
	output reg [7:0] data = 8'd0,
	output reg wr = 1'b0,
	output wire active      // cs_n low (clk domain)
);

// ---------------- sck domain ----------------

// bit counter, restarts at every assertion of cs_n
reg [2:0] bitcnt = 3'd0;
always @(posedge sck or posedge cs_n)
	if (cs_n)
		bitcnt <= 3'd0;
	else
		bitcnt <= bitcnt + 3'd1;

// shift register and byte handover; not reset: the last byte must survive cs_n going high
reg [6:0] shreg = 7'd0;
reg [7:0] byte_hold = 8'd0;
reg byte_tgl = 1'b0;
always @(posedge sck)
	if (!cs_n) begin
		shreg <= { shreg[5:0], mosi };
		if (bitcnt == 3'd7) begin
			byte_hold <= { shreg, mosi };
			byte_tgl <= ~byte_tgl;
		end
	end

// ---------------- clk domain ----------------

reg [2:0] tgl_sync = 3'd0;
reg [1:0] cs_sync = 2'b11;
reg [2:0] idx = 3'd0;      // 0 = type, 1..4 = address, 5 = data
reg [7:0] type_r = 8'd0;
reg [31:0] next_addr = 32'd0;

always @(posedge clk) begin
	tgl_sync <= { tgl_sync[1:0], byte_tgl };
	cs_sync <= { cs_sync[0], cs_n };
	wr <= 1'b0;
	if (tgl_sync[2] != tgl_sync[1]) begin
		// a new byte (before the idle reset below, so the last byte of a burst is not lost
		// when cs_n rises right after it)
		case (idx)
			3'd0: type_r <= byte_hold;
			3'd1: next_addr[31:24] <= byte_hold;
			3'd2: next_addr[23:16] <= byte_hold;
			3'd3: next_addr[15:8] <= byte_hold;
			3'd4: next_addr[7:0] <= byte_hold;
			default: begin
				data <= byte_hold;
				addr <= next_addr;
				wr <= 1'b1;
				next_addr <= next_addr + 32'd1;
			end
		endcase
		if (idx != 3'd5)
			idx <= idx + 3'd1;
	end
	else if (cs_sync[1])
		// idle: the next byte is the type of a new burst
		idx <= 3'd0;
end

assign btype = type_r;
assign active = ~cs_sync[1];

endmodule
