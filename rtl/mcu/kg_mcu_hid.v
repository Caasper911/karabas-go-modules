`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_mcu_hid.v

 The input devices of the MCU link (a decoder on the frame bus of kg_mcu_link):
   KBD n d          the USB keyboard report: kb[n*8 +: 8] (0 = modifiers, 1..6 = key codes)
   MOUSE 0..3 d     ms_x, ms_y (deltas), ms_z (wheel, 4 bits), ms_b (buttons, 3 bits);
                    ms_b ends a report: ms_upd toggles, ms_stb is one clock
   JOY 0..3 d       joy_l[7:0], joy_l[12:8], joy_r[7:0], joy_r[12:8]
                    (on, up, down, left, right, start, a, b, c, x, y, z, mode)
   PS2_SCANCODE n d n 0: kb_scancode (toggles kb_scancode_upd), 1: xt_scancode (xt_scancode_upd)
*/

module kg_mcu_hid (
	input wire clk,
	input wire rx_stb,
	input wire [7:0] rx_cmd,
	input wire [7:0] rx_addr,
	input wire [7:0] rx_data,

	output wire [55:0] kb,
	output reg [7:0] ms_x = 8'd0,
	output reg [7:0] ms_y = 8'd0,
	output reg [3:0] ms_z = 4'd0,
	output reg [2:0] ms_b = 3'd0,
	output reg ms_upd = 1'b0,
	output reg ms_stb = 1'b0,
	output wire [12:0] joy_l,
	output wire [12:0] joy_r,
	output reg [7:0] kb_scancode = 8'd0,
	output reg kb_scancode_upd = 1'b0,
	output reg [7:0] xt_scancode = 8'd0,
	output reg xt_scancode_upd = 1'b0
);

`include "kg_mcu_cmds.vh"

// one register per byte: XST builds a write of a part of a vector as a mux over all of it (a
// LUT per bit) instead of a clock enable
reg [7:0] kb0 = 8'd0, kb1 = 8'd0, kb2 = 8'd0, kb3 = 8'd0, kb4 = 8'd0, kb5 = 8'd0, kb6 = 8'd0;
reg [7:0] joy_l_lo = 8'd0, joy_r_lo = 8'd0;
reg [4:0] joy_l_hi = 5'd0, joy_r_hi = 5'd0;
assign kb = { kb6, kb5, kb4, kb3, kb2, kb1, kb0 };
assign joy_l = { joy_l_hi, joy_l_lo };
assign joy_r = { joy_r_hi, joy_r_lo };

always @(posedge clk) begin
	ms_stb <= 1'b0;
	if (rx_stb)
		case (rx_cmd)
			CMD_KBD:
				case (rx_addr)
					8'h00: kb0 <= rx_data;
					8'h01: kb1 <= rx_data;
					8'h02: kb2 <= rx_data;
					8'h03: kb3 <= rx_data;
					8'h04: kb4 <= rx_data;
					8'h05: kb5 <= rx_data;
					8'h06: kb6 <= rx_data;
					default: ;
				endcase
			CMD_MOUSE:
				case (rx_addr)
					8'h00: ms_x <= rx_data;
					8'h01: ms_y <= rx_data;
					8'h02: ms_z <= rx_data[3:0];
					8'h03: begin
						ms_b <= rx_data[2:0];
						ms_upd <= ~ms_upd;
						ms_stb <= 1'b1;
					end
					default: ;
				endcase
			CMD_JOY:
				case (rx_addr)
					8'h00: joy_l_lo <= rx_data;
					8'h01: joy_l_hi <= rx_data[4:0];
					8'h02: joy_r_lo <= rx_data;
					8'h03: joy_r_hi <= rx_data[4:0];
					default: ;
				endcase
			CMD_PS2_SCANCODE:
				case (rx_addr)
					8'h00: begin
						kb_scancode <= rx_data;
						kb_scancode_upd <= ~kb_scancode_upd;
					end
					8'h01: begin
						xt_scancode <= rx_data;
						xt_scancode_upd <= ~xt_scancode_upd;
					end
					default: ;
				endcase
			default: ;
		endcase
end

endmodule
