`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_mcu_esp.v

 The serial port of the ESP8266 module bridged by the MCU (CMD_ESP_UART, karabas-go-firmware
 lib/EspSerial; a decoder on the frame bus of kg_mcu_link, one transmit port). The core has the
 uart and its fifos (esp8266.vhd of karabas-go-core-menu):
 - CMD_ESP_UART x d of the mcu: a byte to send to the ESP, esp_tx_data = d, esp_tx_wr one clock;
 - a byte received from the ESP: esp_rx_data held with esp_rx_wr until esp_rx_ack (one clock),
   goes out as CMD_ESP_UART 00 d when the queue has room and not in the clock after an ack (the
   sender is putting up its next byte then), as the words of kg_mcu_img. The menu core took the
   byte on a strobe: when the mcu did not read for 512 frames, the queue was full and the bytes
   were lost; held, they wait in the receive fifo of the core, whose CTS stops the ESP.
*/

module kg_mcu_esp (
	input wire clk,
	input wire rx_stb,
	input wire [7:0] rx_cmd,
	/* verilator lint_off UNUSEDSIGNAL */
	input wire [7:0] rx_addr,      // not used: the mcu sends 00
	/* verilator lint_on UNUSEDSIGNAL */
	input wire [7:0] rx_data,

	output reg [7:0] esp_tx_data = 8'd0,
	output reg esp_tx_wr = 1'b0,

	input wire [7:0] esp_rx_data,
	input wire esp_rx_wr,
	output reg esp_rx_ack = 1'b0,

	output wire tx_req,
	output wire [23:0] tx_data,
	input wire tx_grant,
	input wire tx_full
);

`include "kg_mcu_cmds.vh"

always @(posedge clk) begin
	esp_tx_wr <= 1'b0;
	if (rx_stb && rx_cmd == CMD_ESP_UART) begin
		esp_tx_data <= rx_data;
		esp_tx_wr <= 1'b1;
	end
	esp_rx_ack <= tx_grant;
end

assign tx_req = esp_rx_wr && !esp_rx_ack && !tx_full;
assign tx_data = { CMD_ESP_UART, 8'h00, esp_rx_data };

endmodule
