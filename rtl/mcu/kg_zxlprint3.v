`timescale 1ns / 1ps
`default_nettype none

// ZX LPRINT III transport on the kg_mcu_link frame bus, all signals use clk.
// 13 00 xx: raw printer byte; 14 00 00: subscribe/request status;
// 14 00 ss received: status only, bit 7 BUSY (not a byte acknowledgement).
// Request status after reset; report BUSY until the first status arrives.
// printer_wr is a one-clock strobe with printer_data. The producer must obey
// printer_busy; writes while busy are ignored. One byte waits for tx_grant,
// which must guarantee queue space (as in kg_mcu_link). No per-byte ACK.
module kg_zxlprint3 (
    input wire clk, reset,
    input wire rx_stb,
    input wire [7:0] rx_cmd, rx_addr, rx_data,
    input wire [7:0] printer_data,
    input wire printer_wr,
    output wire printer_busy,
    output reg [7:0] printer_status = 8'h80,
    output reg printer_status_valid = 1'b0,
    output wire tx_req,
    output wire [23:0] tx_data,
    input wire tx_grant
);

`include "kg_mcu_cmds.vh"

reg query_pending = 1'b1;
reg byte_pending = 1'b0;
reg [7:0] byte_data = 8'd0;

assign printer_busy = reset || !printer_status_valid || printer_status[7] || query_pending || byte_pending;
assign tx_req = !reset && (query_pending || byte_pending);
assign tx_data = query_pending ? {CMD_PRINTER_STATUS, 16'h0000} : {CMD_PRINTER_DATA, 8'h00, byte_data};

always @(posedge clk or posedge reset) begin
    if (reset) begin
        query_pending <= 1'b1;
        byte_pending <= 1'b0;
        byte_data <= 8'd0;
        printer_status <= 8'h80;
        printer_status_valid <= 1'b0;
    end else begin
        if (printer_wr && !printer_busy) begin
            byte_data <= printer_data;
            byte_pending <= 1'b1;
        end

        if (tx_req && tx_grant) begin
            if (query_pending)
                query_pending <= 1'b0;
            else
                byte_pending <= 1'b0;
        end

        if (rx_stb && rx_cmd == CMD_PRINTER_STATUS && rx_addr == 8'h00) begin
            printer_status <= rx_data;
            printer_status_valid <= 1'b1;
        end
    end
end

endmodule
`default_nettype wire
