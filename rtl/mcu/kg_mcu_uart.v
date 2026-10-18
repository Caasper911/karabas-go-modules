`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_mcu_uart.v

 The serial port bridged by the MCU (a decoder on the frame bus of kg_mcu_link, three transmit
 ports, one-clock strobes each):
 - CMD_UART idx d of the mcu: a received byte, rx_data = d, rx_idx = idx (a counter of the mcu:
   a new byte when it changes);
 - tx_wr: a byte to send, CMD_UART 00 d (tx_mode 1: 03 d, the tsconf rs232 at the dll / dlm
   speed); dll_wr / dlm_wr: the divisor of that speed, CMD_UART 01 dll / 02 dlm.
*/

module kg_mcu_uart (
	input wire clk,
	input wire rx_stb,
	input wire [7:0] rx_cmd,
	input wire [7:0] rx_addr,
	input wire [7:0] rx_data,

	output reg [7:0] uart_rx_data = 8'd0,
	output reg [7:0] uart_rx_idx = 8'd0,

	input wire [7:0] uart_tx_data,
	input wire uart_tx_wr,
	input wire uart_tx_mode,
	input wire [7:0] uart_dll,
	input wire uart_dll_wr,
	input wire [7:0] uart_dlm,
	input wire uart_dlm_wr,

	output wire [2:0] tx_req,       // byte, dll, dlm
	output wire [3*24-1:0] tx_data
);

`include "kg_mcu_cmds.vh"

always @(posedge clk)
	if (rx_stb && rx_cmd == CMD_UART) begin
		uart_rx_data <= rx_data;
		uart_rx_idx <= rx_addr;
	end

assign tx_req = { uart_dlm_wr, uart_dll_wr, uart_tx_wr };
assign tx_data = {
	CMD_UART, 8'h02, uart_dlm,
	CMD_UART, 8'h01, uart_dll,
	CMD_UART, uart_tx_mode ? 8'h03 : 8'h00, uart_tx_data };

endmodule
