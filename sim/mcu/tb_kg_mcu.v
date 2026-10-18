`timescale 1ns / 1ps

// kg_mcu.v beyond what mcu.vhd of nanomig has (tb_eq_mcu compares that part), iverilog. Four
// instances on one spi bus, replies read from the one selected:
//   ts  tsconf: ps/2 and xt scancodes, uart mode / dll / dlm, debug values, FT_RESET, rtc
//       registers D sent and F0-FF not, no file loader;
//   rk  rk86 / spec256: ioctl file loader on its own signals, a write per address change;
//   alf alf / nes: the file commands 0C-0E;
//   nm  nanomig: a full reply queue holds a file mounter word until there is room.
// Also: the chip select filter (a short high spike in a frame; ts filters, rk does not), a frame
// decoded once (MS_UPD and the scancode flags toggle once).
// Ends with "tb_kg_mcu: N errors".

module tb_kg_mcu;

reg clk = 1'b0;
always #17.65 clk = ~clk;

integer errors = 0;
task fail(input [8*72-1:0] what);
	begin
		if (errors < 30) $display("%t ERROR: %0s", $time, what);
		errors = errors + 1;
	end
endtask

reg cs_n = 1'b1, sck = 1'b0, mosi = 1'b0, burst_cs_n = 1'b1;
reg [1:0] sel = 2'd0; // whose replies are read: 0 ts, 1 rk, 2 alf, 3 nm
wire [3:0] miso;
wire miso_sel = miso[sel];

// core side
reg [7:0] rtc_a = 8'h00, rtc_di = 8'h00;
reg rtc_cs = 1'b0, rtc_wr_n = 1'b1;
reg [7:0] uart_tx_data = 8'h00, uart_dll = 8'h00, uart_dlm = 8'h00;
reg uart_tx_wr = 1'b0, uart_tx_mode = 1'b0, uart_dll_wr = 1'b0, uart_dlm_wr = 1'b0;
reg [23:0] matrix_cmd = 24'h0;
reg matrix_cmd_wr = 1'b0;
reg [15:0] debug_addr = 16'h0000, debug_data = 16'h0000;
reg img_q_wr = 1'b0;
reg [23:0] img_q_di = 24'h0;

`define INPUTS(i) \
	.CLK(clk), .N_RESET(1'b1), \
	.MCU_MOSI(mosi), .MCU_MISO(miso[i]), .MCU_SCK(sck), .MCU_SS(cs_n), \
	.MCU_SPI_FT_SS(1'b1), .MCU_SPI_SD2_SS(1'b1), .MCU_BURST_CS_N(burst_cs_n), \
	.RTC_A(rtc_a), .RTC_DI(rtc_di), .RTC_CS(rtc_cs), .RTC_WR_N(rtc_wr_n), \
	.UART_TX_DATA(uart_tx_data), .UART_TX_WR(uart_tx_wr), .UART_TX_MODE(uart_tx_mode), \
	.UART_DLM(uart_dlm), .UART_DLL(uart_dll), .UART_DLM_WR(uart_dlm_wr), .UART_DLL_WR(uart_dll_wr), \
	.FT_MISO(1'b1), .SD2_MISO(1'b1), \
	.MATRIX_CMD(matrix_cmd), .MATRIX_CMD_WR(matrix_cmd_wr), .DEBUG_ADDR(debug_addr), .DEBUG_DATA(debug_data), \
	.IMG_Q_WR(img_q_wr), .IMG_Q_DI(img_q_di)

// tsconf
wire ts_ms_upd, ts_kb_upd, ts_xt_upd, ts_ft_spi, ts_ft_vga, ts_ft_reset, ts_busy;
wire [7:0] ts_kb_sc, ts_xt_sc;
wire [15:0] ts_softsw;
kg_mcu #(.CS_FILTER(3), .RTC_SKIP_0D(0), .RTC_SEND_LIMIT('hF0), .ENABLE_DEBUG(1), .ENABLE_IMG(0),
	.ENABLE_FILE(0), .ENABLE_SD2(0)) ts(`INPUTS(0),
	.MS_UPD(ts_ms_upd), .KB_SCANCODE(ts_kb_sc), .KB_SCANCODE_UPD(ts_kb_upd), .XT_SCANCODE(ts_xt_sc),
	.XT_SCANCODE_UPD(ts_xt_upd), .FT_SPI_ON(ts_ft_spi), .FT_VGA_ON(ts_ft_vga), .FT_RESET(ts_ft_reset),
	.SOFTSW_COMMAND(ts_softsw), .BUSY(ts_busy));

// rk86 / spec256 (no chip select filter: the spike test shows what it is for)
wire rk_reset, rk_active, rk_wr, rk_romwr;
wire [31:0] rk_size, rk_addr;
wire [7:0] rk_data;
wire [15:0] rk_softsw;
kg_mcu #(.CS_FILTER(0), .ENABLE_FILE(1), .FILE_CMDS(0), .FILE_WR_EACH(0), .FILE_TO_ROM(0)) rk(`INPUTS(1),
	.FILELOAD_RESET(rk_reset), .FILELOAD_ACTIVE(rk_active), .FILELOAD_SIZE(rk_size),
	.FILELOAD_ADDR(rk_addr), .FILELOAD_DATA(rk_data), .FILELOAD_WR(rk_wr), .ROMLOAD_WR(rk_romwr),
	.SOFTSW_COMMAND(rk_softsw));

// alf / nes
wire alf_reset, alf_active, alf_wr;
wire [31:0] alf_addr;
wire [7:0] alf_data;
kg_mcu #(.ENABLE_FILE(1), .FILE_CMDS(1), .FILE_WR_EACH(0), .FILE_TO_ROM(0)) alf(`INPUTS(2),
	.FILELOAD_RESET(alf_reset), .FILELOAD_ACTIVE(alf_active), .FILELOAD_ADDR(alf_addr),
	.FILELOAD_DATA(alf_data), .FILELOAD_WR(alf_wr));

// nanomig
wire nm_ack;
kg_mcu #(.BURST_MAX_MHZ(32), .ENABLE_IMG(1)) nm(`INPUTS(3), .IMG_Q_ACK(nm_ack));

// ---------------- mcu model ----------------

task spi_byte(input [7:0] tx, output [7:0] rx);
	integer k;
	begin
		for (k = 7; k >= 0; k = k - 1) begin
			mosi = tx[k];
			#31;
			sck = 1'b1;
			rx[k] = miso_sel;
			#31;
			sck = 1'b0;
		end
	end
endtask

reg [23:0] rxq [0:1023];
integer rx_n = 0, rx_rd = 0;
reg [7:0] rc, ra, rd;
reg glitch = 1'b0; // a 50 ns high spike on cs_n in the middle of the second byte
task frame(input [7:0] c, input [7:0] a, input [7:0] d);
	begin
		cs_n = 1'b0;
		#100;
		spi_byte(c, rc);
		if (glitch) fork
			spi_byte(a, ra);
			begin #250; cs_n = 1'b1; #50; cs_n = 1'b0; end
		join
		else
			spi_byte(a, ra);
		spi_byte(d, rd);
		#50;
		cs_n = 1'b1;
		#500;
		if (rc !== 8'hFF) begin
			rxq[rx_n] = { rc, ra, rd };
			rx_n = rx_n + 1;
		end
	end
endtask

task expect_reply(input [23:0] w);
	integer n;
	begin
		n = 0;
		while (rx_rd == rx_n && n < 20) begin frame(8'hFF, 8'h00, 8'h00); n = n + 1; end
		if (rx_rd == rx_n) begin
			$display("%t ERROR: no reply, expected %h", $time, w);
			errors = errors + 1;
		end
		else begin
			if (rxq[rx_rd] !== w) begin
				$display("%t ERROR: reply %h, expected %h", $time, rxq[rx_rd], w);
				errors = errors + 1;
			end
			rx_rd = rx_rd + 1;
		end
	end
endtask

task expect_no_reply;
	integer n;
	begin
		for (n = 0; n < 6; n = n + 1) frame(8'hFF, 8'h00, 8'h00);
		while (rx_rd != rx_n) begin
			$display("%t ERROR: unexpected reply %h", $time, rxq[rx_rd]);
			errors = errors + 1;
			rx_rd = rx_rd + 1;
		end
	end
endtask

task flush; // drop what is queued
	integer n;
	begin
		for (n = 0; n < 6; n = n + 1) frame(8'hFF, 8'h00, 8'h00);
		rx_rd = rx_n;
	end
endtask

task burst(input [7:0] t, input [31:0] addr, input integer n, input [7:0] base);
	integer k;
	reg [7:0] dummy;
	begin
		burst_cs_n = 1'b0;
		#100;
		spi_byte(t, dummy);
		spi_byte(addr[31:24], dummy);
		spi_byte(addr[23:16], dummy);
		spi_byte(addr[15:8], dummy);
		spi_byte(addr[7:0], dummy);
		for (k = 0; k < n; k = k + 1) spi_byte(base + k, dummy);
		#100;
		burst_cs_n = 1'b1;
		#500;
	end
endtask

task strobe_uart(input mode, input [7:0] d);
	begin
		@(negedge clk);
		uart_tx_data = d; uart_tx_mode = mode; uart_tx_wr = 1'b1;
		@(negedge clk);
		uart_tx_wr = 1'b0;
	end
endtask

task host_rtc_write(input [7:0] a, input [7:0] d);
	begin
		@(negedge clk);
		rtc_a = a; rtc_di = d; rtc_cs = 1'b1; rtc_wr_n = 1'b0;
		@(negedge clk);
		rtc_cs = 1'b0; rtc_wr_n = 1'b1;
	end
endtask

// ---------------- monitors ----------------

integer ts_ms_tg = 0, ts_kb_tg = 0, ts_xt_tg = 0;
reg ts_ms_p = 1'b0, ts_kb_p = 1'b0, ts_xt_p = 1'b0;
always @(posedge clk) begin
	if (ts_ms_upd !== ts_ms_p) ts_ms_tg = ts_ms_tg + 1;
	if (ts_kb_upd !== ts_kb_p) ts_kb_tg = ts_kb_tg + 1;
	if (ts_xt_upd !== ts_xt_p) ts_xt_tg = ts_xt_tg + 1;
	ts_ms_p = ts_ms_upd; ts_kb_p = ts_kb_upd; ts_xt_p = ts_xt_upd;
end

integer acks = 0;
always @(posedge clk) if (nm_ack) acks = acks + 1;

reg [39:0] rk_log [0:255], alf_log [0:255];
integer rk_n = 0, alf_n = 0, rk_resets = 0, rk_romwrs = 0;
always @(posedge clk) begin
	if (rk_wr) begin rk_log[rk_n] = { rk_addr, rk_data }; rk_n = rk_n + 1; end
	if (alf_wr) begin alf_log[alf_n] = { alf_addr, alf_data }; alf_n = alf_n + 1; end
	if (rk_reset) rk_resets = rk_resets + 1;
	if (rk_romwr) rk_romwrs = rk_romwrs + 1;
end

// ---------------- test ----------------

integer i, n0, n1;
initial begin
	#1000;
	flush;
	frame(8'hFE, 8'h00, 8'h00); // INIT_DONE
	if (ts_busy !== 1'b0) fail("BUSY");

	// ---- tsconf: a report toggles MS_UPD once, scancodes ----
	frame(8'h02, 8'h03, 8'h01);
	frame(8'h0B, 8'h00, 8'h1C);
	frame(8'h0B, 8'h01, 8'h9C);
	if (ts_ms_tg != 1 || ts_kb_tg != 1 || ts_xt_tg != 1) fail("MS_UPD / scancode flags not toggled once per frame");
	if (ts_kb_sc !== 8'h1C || ts_xt_sc !== 8'h9C) fail("scancodes");

	// ---- tsconf: CONTROL with FT_RESET ----
	frame(8'h09, 8'h00, 8'h13);
	if ({ ts_ft_spi, ts_ft_vga, ts_ft_reset } !== 3'b111) fail("CONTROL 13");
	frame(8'h09, 8'h00, 8'h00);
	if ({ ts_ft_spi, ts_ft_vga, ts_ft_reset } !== 3'b000) fail("CONTROL 00");

	// ---- tsconf: uart modes and divisor ----
	flush;
	strobe_uart(1'b0, 8'h41);
	strobe_uart(1'b1, 8'h42);
	@(negedge clk); uart_dll = 8'h0C; uart_dll_wr = 1'b1; @(negedge clk); uart_dll_wr = 1'b0;
	@(negedge clk); uart_dlm = 8'h01; uart_dlm_wr = 1'b1; @(negedge clk); uart_dlm_wr = 1'b0;
	expect_reply(24'hFC_00_41);
	expect_reply(24'hFC_03_42);
	expect_reply(24'hFC_01_0C);
	expect_reply(24'hFC_02_01);
	expect_no_reply;

	// ---- tsconf: debug values; both at once, and with a uart byte in the same clock ----
	@(negedge clk); debug_addr = 16'h1234; debug_data = 16'h5678; uart_tx_data = 8'h43; uart_tx_mode = 0; uart_tx_wr = 1'b1;
	@(negedge clk); uart_tx_wr = 1'b0;
	expect_reply(24'hFC_00_43);
	expect_reply(24'h30_1234);
	expect_reply(24'h31_5678);
	expect_no_reply;
	@(negedge clk); debug_data = 16'h9ABC;
	expect_reply(24'h31_9ABC);
	expect_no_reply;

	// ---- tsconf: rtc registers to the mcu: D yes, C no, F0 up no ----
	host_rtc_write(8'h0D, 8'h80);
	host_rtc_write(8'h0C, 8'h40);
	host_rtc_write(8'hF0, 8'h01);
	host_rtc_write(8'hEF, 8'h02);
	expect_reply(24'hFA_0D_80);
	expect_reply(24'hFA_EF_02);
	expect_no_reply;

	// ---- rk86 / spec256: ioctl on FILELOAD_*, a write per address change ----
	frame(8'h50, 8'h00, 8'h01);                         // slot: FILELOAD_RESET
	if (rk_resets != 1) fail("FILELOAD_RESET pulses");
	for (i = 0; i < 4; i = i + 1) frame(8'h51, i, 8'h10 * (i + 1));
	if (rk_size !== 32'h40302010) fail("FILELOAD_SIZE");
	frame(8'h55, 8'h00, 8'h01);
	if (rk_active !== 1'b1) fail("FILELOAD_ACTIVE");
	frame(8'h52, 8'h00, 8'h02);
	frame(8'h52, 8'h01, 8'h00);
	frame(8'h52, 8'h02, 8'h00);
	frame(8'h53, 8'h00, 8'hA0);
	frame(8'h53, 8'h01, 8'hA1);
	frame(8'h53, 8'h01, 8'hA2);                         // the same address: not written
	burst(8'h53, 32'h00000300, 4, 8'hB0);
	// the file commands of alf and the rom loader do not touch these
	frame(8'h0E, 8'h00, 8'h03);
	frame(8'h0D, 8'h05, 8'hEE);
	if (rk_n != 6) begin $display("%t ERROR: rk86 file writes %0d, expected 6", $time, rk_n); errors = errors + 1; end
	if (rk_log[0] !== 40'h00000200_A0 || rk_log[1] !== 40'h00000201_A1 || rk_log[2] !== 40'h00000300_B0 ||
	    rk_log[5] !== 40'h00000303_B3) fail("rk86 file writes");
	if (rk_romwrs != 0) fail("rk86 rom writes from the file loader");

	// ---- alf: FILELOADER levels, FILEBANK / FILEDATA ----
	if (alf_reset !== 1'b1 || alf_active !== 1'b1) fail("alf FILELOADER 03");
	frame(8'h0C, 8'h00, 8'h00);
	frame(8'h0C, 8'h01, 8'h01);
	frame(8'h0C, 8'h02, 8'h00);
	frame(8'h0D, 8'h07, 8'hC7);
	burst(8'h0D, 32'h00020010, 2, 8'hD0);
	frame(8'h0E, 8'h00, 8'h00);
	if (alf_reset !== 1'b0 || alf_active !== 1'b0) fail("alf FILELOADER 00");
	// alf saw 0D 05 EE above (address 0000_0005) and these three
	if (alf_n != 4 || alf_log[1] !== 40'h00010007_C7 || alf_log[3] !== 40'h00020011_D1) fail("alf file writes");

	// ---- chip select filter: a 50 ns high spike in a frame ----
	glitch = 1'b1;
	frame(8'h05, 8'h12, 8'h34);
	glitch = 1'b0;
	if (ts_softsw !== 16'h1234) fail("frame with a cs spike lost with the filter");
	if (rk_softsw === 16'h1234) fail("frame with a cs spike taken without the filter (the test does not test)");
	frame(8'h05, 8'h00, 8'h00);

	// ---- nanomig: a full reply queue ----
	// 520 matrix words without a frame: the queue fills at 512 (a NOPE may be first in it)
	@(negedge clk);
	for (i = 0; i < 520; i = i + 1) begin
		matrix_cmd = { 8'h70, i[15:0] }; matrix_cmd_wr = 1'b1;
		@(negedge clk);
	end
	matrix_cmd_wr = 1'b0;
	if (nm.u_link.u_queue.count != 512) fail("queue not full at 512");
	// a file mounter word waits while it is full: no ack (a word acked then would be lost)
	img_q_di = 24'h43_00_01; img_q_wr = 1'b1;
	acks = 0;
	repeat (20) @(negedge clk);
	if (acks != 0) fail("IMG_Q_ACK while the queue is full");
	sel = 2'd3;
	n0 = rx_n;
	frame(8'hFF, 8'h00, 8'h00);                         // takes a word: room for one
	repeat (10) @(negedge clk);
	img_q_wr = 1'b0;
	if (acks != 1 || nm.u_link.u_queue.count != 512) fail("file mounter word not taken once after a pop");
	// out in order: matrix words 0, 1, ... (510 or 511 of them), then the file mounter word
	for (i = 0; i < 516; i = i + 1) frame(8'hFF, 8'h00, 8'h00);
	n1 = 0;
	while (n0 + n1 < rx_n && rxq[n0 + n1] === { 8'h70, n1[15:0] }) n1 = n1 + 1;
	if (n1 < 510 || rxq[n0 + n1] !== 24'h43_00_01 || n0 + n1 + 1 != rx_n) begin
		$display("%t ERROR: after the full queue: %0d matrix words in order, then %h, %0d words in all",
			$time, n1, rxq[n0 + n1], rx_n - n0);
		errors = errors + 1;
	end
	sel = 2'd0;

	$display("tb_kg_mcu: %0d errors", errors);
	$finish;
end

initial begin
	#200000000;
	$display("ERROR: timeout");
	$display("tb_kg_mcu: 1 errors");
	$finish;
end

endmodule
