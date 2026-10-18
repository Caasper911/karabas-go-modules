`timescale 1ns / 1ps
`default_nettype wire

/*
 audio_peaks.v

 Audio peaks for the level meters of the mcu (dot matrix), as audio_peaks_writer of
 karabas-go-core-profi (rtl/mcu/dot_matrix.v): the highest absolute sample of each channel over
 a period goes to the mcu link (MATRIX_CMD of mcu.vhd) as CMD_AUDIO_PEAKS_L / _R, high byte in the
 address field, low byte in the data field (karabas-go-firmware docs/protocol.md).

 Smaller than the profi one: the period is 2^PERIOD_BITS clocks (2^19 at 28 MHz = 18.5 ms, profi
 sends every 20 ms), and the absolute value is the ones' complement of a negative sample (one
 step off, a meter does not see it).
*/

module audio_peaks #(
	parameter PERIOD_BITS = 19
) (
	input wire clk,

	input wire signed [15:0] audio_l,
	input wire signed [15:0] audio_r,

	output reg cmd_wr = 1'b0,    // one clock, a frame to the mcu
	output reg [23:0] cmd = 24'd0
);

localparam [7:0] CMD_AUDIO_PEAKS_L = 8'h70;
localparam [7:0] CMD_AUDIO_PEAKS_R = 8'h71;

// 0..32767 per channel, shifted up to 0..65534 on the link as the profi peaks
wire [14:0] abs_l = audio_l[14:0] ^ {15{audio_l[15]}};
wire [14:0] abs_r = audio_r[14:0] ^ {15{audio_r[15]}};

reg [14:0] peak_l = 15'd0, peak_r = 15'd0;
reg [PERIOD_BITS-1:0] cnt = 0;

always @(posedge clk) begin
	cnt <= cnt + 1'd1;
	cmd_wr <= 1'b0;

	// the end of a period: L, then R in the next clock (mcu.vhd takes one frame per clock),
	// then a new period
	if (&cnt) begin
		cmd_wr <= 1'b1;
		cmd <= { CMD_AUDIO_PEAKS_L, peak_l, 1'b0 };
	end
	else if (cnt == 0) begin
		cmd_wr <= 1'b1;
		cmd <= { CMD_AUDIO_PEAKS_R, peak_r, 1'b0 };
		peak_l <= abs_l;
		peak_r <= abs_r;
	end
	else begin
		if (abs_l > peak_l) peak_l <= abs_l;
		if (abs_r > peak_r) peak_r <= abs_r;
	end
end

endmodule
