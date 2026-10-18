`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_mcu_debug.v

 Debug values of the core on the display of the mcu (two transmit ports of kg_mcu_link): a
 change of debug_addr goes out as CMD_DEBUG_ADDR, of debug_data as CMD_DEBUG_DATA. A request
 stays up until it is granted, so the last value always reaches the mcu.
*/

module kg_mcu_debug (
	input wire clk,
	input wire [15:0] debug_addr,
	input wire [15:0] debug_data,

	output wire [1:0] tx_req,        // addr, data
	output wire [2*24-1:0] tx_data,
	input wire [1:0] tx_grant
);

`include "kg_mcu_cmds.vh"

reg [15:0] prev_addr = 16'd0, prev_data = 16'd0;

always @(posedge clk) begin
	if (tx_grant[0])
		prev_addr <= debug_addr;
	if (tx_grant[1])
		prev_data <= debug_data;
end

assign tx_req = { debug_data != prev_data, debug_addr != prev_addr };
assign tx_data = { CMD_DEBUG_DATA, debug_data, CMD_DEBUG_ADDR, debug_addr };

endmodule
