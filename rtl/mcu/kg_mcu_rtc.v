`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_mcu_rtc.v

 The clock registers shared with the MCU (a decoder on the frame bus of kg_mcu_link, one
 transmit port): a 256 x 8 RAM that the core reads (rtc_a -> rtc_do, a clock later) and writes,
 and the mcu keeps in step with its clock chip.
 - CMD_RTC a d of the mcu writes register a.
 - A write of the core (rtc_cs and !rtc_wr_n for one clock, not while busy) goes to the RAM and,
   for the registers the mcu keeps, as CMD_RTC a d to the mcu (tx_req, a one-clock strobe):
   not register C, nor D with SKIP_0D (MC146818: flags), nor from SEND_LIMIT up (tsconf: F0, its
   own registers there).
 The mcu sets the registers at its start (between INIT_START and INIT_DONE, busy).
*/

module kg_mcu_rtc #(
	parameter SKIP_0D = 1,
	parameter SEND_LIMIT = 256
) (
	input wire clk,
	input wire rx_stb,
	input wire [7:0] rx_cmd,
	input wire [7:0] rx_addr,
	input wire [7:0] rx_data,
	input wire busy,

	input wire [7:0] rtc_a,
	input wire [7:0] rtc_di,
	output wire [7:0] rtc_do,
	input wire rtc_cs,
	input wire rtc_wr_n,

	output wire tx_req,
	output wire [23:0] tx_data
);

`include "kg_mcu_cmds.vh"

wire host_wr = rtc_cs && !rtc_wr_n && !busy;
localparam [8:0] LIMIT = SEND_LIMIT;
assign tx_req = host_wr && rtc_a != 8'h0C && !(SKIP_0D && rtc_a == 8'h0D) && { 1'b0, rtc_a } < LIMIT;
assign tx_data = { CMD_RTC, rtc_a, rtc_di };

// a write of the mcu waits a clock behind one of the core
reg [7:0] mcu_a = 8'd0, mcu_d = 8'd0;
reg mcu_req = 1'b0, mcu_ack = 1'b0;
reg w = 1'b0;
reg [7:0] wa = 8'd0, wd = 8'd0;

always @(posedge clk) begin
	if (rx_stb && rx_cmd == CMD_RTC) begin
		mcu_a <= rx_addr;
		mcu_d <= rx_data;
		mcu_req <= ~mcu_req;
	end
	w <= 1'b0;
	if (host_wr) begin
		w <= 1'b1;
		wa <= rtc_a;
		wd <= rtc_di;
	end
	else if (mcu_req != mcu_ack) begin
		w <= 1'b1;
		wa <= mcu_a;
		wd <= mcu_d;
		mcu_ack <= mcu_req;
	end
end

kg_sdpram #(.DW(8), .AW(8)) u_ram(
	.clka(clk), .wea(w), .addra(wa), .dina(wd),
	.clkb(clk), .enb(1'b1), .addrb(rtc_a), .doutb(rtc_do)
);

endmodule
