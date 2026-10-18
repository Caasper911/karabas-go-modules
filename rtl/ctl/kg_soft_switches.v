`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_soft_switches.v

 The OSD switches of the mcu (CMD_SWITCHES, SOFTSW_COMMAND of mcu.vhd): command = index, value.
 A command is taken when it changes, as the soft_switches.vhd of the cores: register index gets
 the value, upd is one clock. The core cuts its fields out of regs (register n is
 regs[n*8 +: 8]); XST removes the bits it does not use. Indexes from N up are ignored.
*/

module kg_soft_switches #(
	parameter N = 16,                  // registers
	parameter [N*8-1:0] INIT = 0       // their values before the first command
) (
	input wire clk,
	input wire [15:0] command,
	output reg [N*8-1:0] regs = INIT,
	output reg upd = 1'b0
);

reg [15:0] prev = 16'hFFFF;

integer i;
always @(posedge clk) begin
	upd <= 1'b0;
	if (command != prev) begin
		prev <= command;
		for (i = 0; i < N; i = i + 1)
			if (command[15:8] == i[7:0]) begin
				regs[i*8 +: 8] <= command[7:0];
				upd <= 1'b1;
			end
	end
end

endmodule
