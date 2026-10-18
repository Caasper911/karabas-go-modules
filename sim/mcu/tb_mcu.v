`timescale 1ns / 1ps

// The MCU link: mcu.vhd (spi_slave, burst_rx, the reply queue) with a model of the mcu on the
// spi link (karabas-go-firmware docs/protocol.md, docs/burst_protocol.md).
// - every command the core decodes: keyboard, mouse (MS_UPD), joysticks, buttons, switches, osd,
//   hw setup, control (FT), uart, init start / done (BUSY), IMG_PHYS;
// - the reply queue: CAPS, uart bytes, rtc writes of the host (not registers C and D), matrix
//   frames, IMG_Q frames (held until IMG_Q_ACK), all in order, NOPE when there is nothing;
// - rtc: CMD_RTC of the mcu to the register ram, read by the host;
// - the rom loader (ROMBANK / ROMDATA, a write per address change) and the ioctl loader (a write
//   per byte, also at the same offset), classic frames and bursts;
// - the classic slave is not selected during a burst: spikes on MCU_SS while a burst shifts
//   lose no reply word;
// - MISO / SCK / MOSI / CS of the FT812 and SD2 chip selects, N_RESET of the queue.
// A frame shifts the reply word the core popped after the previous frame. Ends with
// "tb_mcu: N errors". `define KG_MCU: kg_mcu.v in place of mcu.vhd.

module tb_mcu;

parameter FRAME_GAP = 500; // ns between two classic frames of the mcu (CS high)

reg clk = 1'b0;
always #17.65 clk = ~clk; // 28.33 MHz

integer errors = 0;
task fail(input [8*64-1:0] what);
	begin
		if (errors < 30) $display("%t ERROR: %0s", $time, what);
		errors = errors + 1;
	end
endtask

// ---------------- dut ----------------

reg n_reset = 1'b1;
reg cs_n = 1'b1, sck = 1'b0, mosi = 1'b0, burst_cs_n = 1'b1;
reg ft_ss = 1'b1, sd2_ss = 1'b1, ft_miso = 1'b1, sd2_miso = 1'b1;
wire miso;

reg [7:0] rtc_a = 8'h00, rtc_di = 8'h00;
reg rtc_cs = 1'b0, rtc_wr_n = 1'b1;
reg [7:0] uart_tx_data = 8'h00;
reg uart_tx_wr = 1'b0;
reg [23:0] matrix_cmd = 24'h0;
reg matrix_cmd_wr = 1'b0;
reg img_q_wr = 1'b0;
reg [23:0] img_q_di = 24'h0;

wire [7:0] ms_x, ms_y, kb_status, kb0, kb1, kb2, kb3, kb4, kb5, rtc_do, uart_rx_data, uart_rx_idx;
wire [7:0] romload_data, hwid;
wire [3:0] ms_z;
wire [2:0] ms_b;
wire ms_upd;
wire [12:0] joy_l, joy_r;
wire [1:0] btns;
wire [15:0] softsw, osd, img_phys;
wire romloader_active, romload_wr, ioctl_active, ft_spi_on, ft_vga_on, dvi_only, busy, burst_ready;
wire [31:0] romload_addr;
wire ft_sck, ft_mosi, ft_cs_n, sd2_sck, sd2_mosi, sd2_cs_n;
wire img_q_ack, img_phys_wr;

`ifdef KG_MCU
// kg_mcu with the nanomig configuration, its chip select filter on
kg_mcu #(.BURST_MAX_MHZ(32), .CS_FILTER(3), .ENABLE_IMG(1)) dut(
	.UART_TX_MODE(1'b0), .UART_DLM(8'h00), .UART_DLL(8'h00), .UART_DLM_WR(1'b0), .UART_DLL_WR(1'b0),
	.DEBUG_ADDR(16'h0000), .DEBUG_DATA(16'h0000),
`else
mcu #(.BURST_MAX_MHZ(32)) dut(
`endif
	.CLK(clk),
	.N_RESET(n_reset),
	.MCU_MOSI(mosi), .MCU_MISO(miso), .MCU_SCK(sck), .MCU_SS(cs_n),
	.MCU_SPI_FT_SS(ft_ss), .MCU_SPI_SD2_SS(sd2_ss),
	.MCU_BURST_CS_N(burst_cs_n), .MCU_BURST_READY(burst_ready),
	.MS_X(ms_x), .MS_Y(ms_y), .MS_B(ms_b), .MS_Z(ms_z), .MS_UPD(ms_upd),
	.KB_STATUS(kb_status), .KB_DAT0(kb0), .KB_DAT1(kb1), .KB_DAT2(kb2), .KB_DAT3(kb3), .KB_DAT4(kb4), .KB_DAT5(kb5),
	.JOY_L(joy_l), .JOY_R(joy_r),
	.BTNS(btns),
	.RTC_A(rtc_a), .RTC_DI(rtc_di), .RTC_DO(rtc_do), .RTC_CS(rtc_cs), .RTC_WR_N(rtc_wr_n),
	.UART_RX_DATA(uart_rx_data), .UART_RX_IDX(uart_rx_idx),
	.UART_TX_DATA(uart_tx_data), .UART_TX_WR(uart_tx_wr),
	.SOFTSW_COMMAND(softsw),
	.ROMLOADER_ACTIVE(romloader_active), .ROMLOAD_ADDR(romload_addr), .ROMLOAD_DATA(romload_data),
	.ROMLOAD_WR(romload_wr), .IOCTL_ACTIVE(ioctl_active),
	.OSD_COMMAND(osd),
	.FT_SPI_ON(ft_spi_on), .FT_VGA_ON(ft_vga_on),
	.FT_SCK(ft_sck), .FT_MOSI(ft_mosi), .FT_MISO(ft_miso), .FT_CS_N(ft_cs_n),
	.SD2_SCK(sd2_sck), .SD2_MOSI(sd2_mosi), .SD2_MISO(sd2_miso), .SD2_CS_N(sd2_cs_n),
	.MATRIX_CMD(matrix_cmd), .MATRIX_CMD_WR(matrix_cmd_wr),
	.HWID(hwid), .DVI_ONLY(dvi_only),
	.IMG_MOUNTED(), .IMG_SIZE(), .IMG_DATA_WR(), .IMG_DATA_ADDR(), .IMG_DATA(),
	.IMG_RESULT_WR(), .IMG_RESULT(), .IMG_SUM(),
	.IMG_Q_WR(img_q_wr), .IMG_Q_DI(img_q_di), .IMG_Q_ACK(img_q_ack),
	.IMG_PHYS_WR(img_phys_wr), .IMG_PHYS(img_phys),
	.BUSY(busy)
);

// ---------------- mcu model: frames ----------------

task spi_byte(input [7:0] tx, output [7:0] rx);
	integer k;
	begin
		for (k = 7; k >= 0; k = k - 1) begin
			mosi = tx[k];
			#31;
			sck = 1'b1;
			rx[k] = miso;
			#31;
			sck = 1'b0;
		end
	end
endtask

// reply words other than NOPE, in the order they came
reg [23:0] rxq [0:1023];
integer rx_n = 0, rx_rd = 0;
integer frames = 0;

reg [7:0] rc, ra, rd;
task frame(input [7:0] c, input [7:0] a, input [7:0] d);
	begin
		cs_n = 1'b0;
		#100;
		spi_byte(c, rc);
		spi_byte(a, ra);
		spi_byte(d, rd);
		#50;
		cs_n = 1'b1;
		#FRAME_GAP;
		frames = frames + 1;
		if (rc !== 8'hFF) begin
			rxq[rx_n] = { rc, ra, rd };
			rx_n = rx_n + 1;
		end
	end
endtask

// polls until a reply word is there, which must be w
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

// a burst: type, address (MSB first), n bytes of data(k) = base + k * step; spikes: a short low
// pulse on the classic chip select over the last two sck edges of every 7th byte (as on Mini G:
// the top lets a low through at once and holds it 3 clocks), then a pause. A selected slave
// shifts two bits and is reset; with sck stopped, the slave without the karabas fix in idle
// requested a reply word for longer than its 2-clock filter.
reg spikes = 1'b0;
reg spike_go = 1'b0;
always @(posedge spike_go) begin
	#420;
	cs_n = 1'b0;
	#110;
	cs_n = 1'b1;
end
task burst(input [7:0] t, input [31:0] addr, input integer n, input [7:0] base, input [7:0] step);
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
		for (k = 0; k < n; k = k + 1) begin
			spike_go = spikes && (k % 7 == 3);
			spi_byte(base + k * step, dummy);
			if (spike_go) #200; // the rp2040 pauses between bytes now and then
			spike_go = 1'b0;
		end
		#100;
		burst_cs_n = 1'b1;
		#FRAME_GAP;
	end
endtask

// ---------------- monitors ----------------

// loader writes
reg [39:0] wlog [0:1023]; // address, data
integer w_n = 0;
always @(posedge clk)
	if (romload_wr) begin
		wlog[w_n] = { romload_addr, romload_data };
		w_n = w_n + 1;
	end

integer phys_n = 0;
always @(posedge clk) if (img_phys_wr) phys_n = phys_n + 1;

// the host side: strobes of one clock
task host_rtc_write(input [7:0] a, input [7:0] d);
	begin
		@(negedge clk);
		rtc_a = a; rtc_di = d; rtc_cs = 1'b1; rtc_wr_n = 1'b0;
		@(negedge clk);
		rtc_cs = 1'b0; rtc_wr_n = 1'b1;
	end
endtask

task host_rtc_read(input [7:0] a, output [7:0] d);
	begin
		@(negedge clk);
		rtc_a = a;
		repeat (2) @(negedge clk);
		d = rtc_do;
	end
endtask

task uart_tx(input [7:0] d);
	begin
		@(negedge clk);
		uart_tx_data = d; uart_tx_wr = 1'b1;
		@(negedge clk);
		uart_tx_wr = 1'b0;
	end
endtask

// ---------------- test ----------------

integer i, w0, mu;
reg [7:0] b;
// a loader write (the arguments cut integer sums to their widths)
task expect_write(input integer k, input [31:0] a, input [7:0] d);
	begin
		if (wlog[k] !== { a, d }) begin
			if (errors < 30) $display("%t ERROR: loader write %0d: %h, expected %h %h", $time, k, wlog[k], a, d);
			errors = errors + 1;
		end
	end
endtask
initial begin
	#1000;
	// the first reply words come from an empty queue: drop them
	for (i = 0; i < 4; i = i + 1) frame(8'hFF, 8'h00, 8'h00);
	rx_rd = rx_n;

	// ---- init, BUSY ----
	if (busy !== 1'b1) fail("BUSY not 1 after configuration");
	frame(8'hFD, 8'h00, 8'h00);
	if (busy !== 1'b1) fail("BUSY after INIT_START");
	frame(8'hFE, 8'h00, 8'h00);
	if (busy !== 1'b0) fail("BUSY after INIT_DONE");
	if (burst_ready !== 1'b1) fail("MCU_BURST_READY");

	// ---- keyboard ----
	for (i = 0; i < 7; i = i + 1) frame(8'h01, i, 8'h11 * (i + 1));
	frame(8'h01, 8'h07, 8'hEE); // no such byte
	if ({ kb_status, kb0, kb1, kb2, kb3, kb4, kb5 } !== 56'h11_22_33_44_55_66_77) fail("keyboard");

	// ---- mouse ----
	mu = ms_upd;
	frame(8'h02, 8'h00, 8'h85);
	frame(8'h02, 8'h01, 8'h7F);
	frame(8'h02, 8'h02, 8'hFD);
	if (ms_upd !== mu) fail("MS_UPD before the buttons");
	frame(8'h02, 8'h03, 8'hFD);
	if ({ ms_x, ms_y, ms_z, ms_b } !== { 8'h85, 8'h7F, 4'hD, 3'h5 }) fail("mouse");
	if (ms_upd !== !mu) fail("MS_UPD not toggled");
	frame(8'h02, 8'h03, 8'h02);
	if (ms_upd !== mu || ms_b !== 3'h2) fail("MS_UPD / MS_B, second report");

	// ---- joysticks ----
	frame(8'h03, 8'h00, 8'hA5);
	frame(8'h03, 8'h01, 8'hF6);
	frame(8'h03, 8'h02, 8'h3C);
	frame(8'h03, 8'h03, 8'hE9);
	if (joy_l !== 13'h16A5 || joy_r !== 13'h093C) fail("joysticks");

	// ---- buttons, switches, osd, hw setup, control, uart rx, IMG_PHYS ----
	frame(8'h04, 8'h01, 8'h01);
	if (btns !== 2'b10) fail("BTNS 1");
	frame(8'h04, 8'h00, 8'h01);
	frame(8'h04, 8'h01, 8'h00);
	if (btns !== 2'b01) fail("BTNS 0");
	frame(8'h05, 8'h12, 8'h34);
	if (softsw !== 16'h1234) fail("SOFTSW_COMMAND");
	frame(8'h20, 8'h56, 8'h78);
	if (osd !== 16'h5678) fail("OSD_COMMAND");
	frame(8'hF9, 8'h00, 8'h5A);
	frame(8'hF9, 8'h01, 8'h01);
	if (hwid !== 8'h5A || dvi_only !== 1'b1) fail("HW_SETUP");
	frame(8'hF9, 8'h01, 8'h00);
	if (dvi_only !== 1'b0) fail("DVI_ONLY off");
	frame(8'h09, 8'h00, 8'h02);
	if (ft_spi_on !== 1'b0 || ft_vga_on !== 1'b1) fail("CONTROL 2");
	frame(8'h09, 8'h00, 8'h01);
	if (ft_spi_on !== 1'b1 || ft_vga_on !== 1'b0) fail("CONTROL 1");
	frame(8'h09, 8'h00, 8'h00);
	frame(8'hFC, 8'h07, 8'hC3);
	if (uart_rx_idx !== 8'h07 || uart_rx_data !== 8'hC3) fail("UART rx");
	frame(8'h46, 8'h01, 8'h02);
	if (phys_n !== 1 || img_phys !== 16'h0102) fail("IMG_PHYS");
	expect_no_reply;

	// ---- CAPS ----
	frame(8'hF7, 8'h00, 8'h00);
	expect_reply(24'hF7_03_20);
	frame(8'hF7, 8'h01, 8'h00); // only the query 00 is answered
	expect_no_reply;

	// ---- the reply queue: uart, rtc writes of the host, matrix, IMG_Q, in order ----
	uart_tx(8'h41);
	uart_tx(8'h42);
	host_rtc_write(8'h07, 8'h55);
	host_rtc_write(8'h0C, 8'h80); // registers C and D: to the ram only
	host_rtc_write(8'h0D, 8'h80);
	@(negedge clk);
	matrix_cmd = 24'h70_12_34; matrix_cmd_wr = 1'b1;
	@(negedge clk);
	matrix_cmd_wr = 1'b0;
	@(negedge clk);
	img_q_di = 24'h42_03_99; img_q_wr = 1'b1;
	@(posedge img_q_ack);
	@(negedge clk);
	img_q_di = 24'h43_00_01; // the next frame right after the ack
	@(posedge img_q_ack);
	@(negedge clk);
	img_q_wr = 1'b0;
	uart_tx(8'h43);
	expect_reply(24'hFC_00_41);
	expect_reply(24'hFC_00_42);
	expect_reply(24'hFA_07_55);
	expect_reply(24'h70_12_34);
	expect_reply(24'h42_03_99);
	expect_reply(24'h43_00_01);
	expect_reply(24'hFC_00_43);
	expect_no_reply;

	// ---- rtc: the host reads what it and the mcu wrote ----
	host_rtc_read(8'h07, b);
	if (b !== 8'h55) fail("rtc register 7 (host write)");
	host_rtc_read(8'h0C, b);
	if (b !== 8'h80) fail("rtc register C (host write)");
	frame(8'hFA, 8'h00, 8'h59);
	frame(8'hFA, 8'h32, 8'h20);
	host_rtc_read(8'h00, b);
	if (b !== 8'h59) fail("rtc register 0 (mcu)");
	host_rtc_read(8'h32, b);
	if (b !== 8'h20) fail("rtc register 32 (mcu)");
	expect_no_reply; // the writes of the mcu do not come back

	// ---- rtc writes of the host while BUSY: not sent ----
	frame(8'hFD, 8'h00, 8'h00);
	host_rtc_write(8'h01, 8'h11);
	expect_no_reply;
	frame(8'hFE, 8'h00, 8'h00);

	// ---- rom loader, classic frames ----
	w0 = w_n;
	frame(8'h08, 8'h00, 8'h01);
	if (romloader_active !== 1'b1) fail("ROMLOADER_ACTIVE");
	frame(8'h06, 8'h00, 8'h34);
	frame(8'h06, 8'h01, 8'h12);
	frame(8'h06, 8'h02, 8'h00);
	for (i = 0; i < 10; i = i + 1) frame(8'h07, i, 8'hA0 + i);
	frame(8'h07, 8'h09, 8'hA9); // the same address again: no write
	frame(8'h08, 8'h00, 8'h00);
	if (w_n - w0 != 10) begin
		$display("%t ERROR: rom loader %0d writes, expected 10", $time, w_n - w0);
		errors = errors + 1;
	end
	for (i = 0; i < 10 && i < w_n - w0; i = i + 1)
		expect_write(w0 + i, 32'h00123400 + i, 8'hA0 + i);

	// ---- rom loader, burst ----
	w0 = w_n;
	frame(8'h08, 8'h00, 8'h01);
	burst(8'h07, 32'h00ABCDF0, 40, 8'h10, 8'h03);
	frame(8'h08, 8'h00, 8'h00);
	if (w_n - w0 != 40) begin
		$display("%t ERROR: burst rom loader %0d writes, expected 40", $time, w_n - w0);
		errors = errors + 1;
	end
	for (i = 0; i < 40 && i < w_n - w0; i = i + 1)
		expect_write(w0 + i, 32'h00ABCDF0 + i, 8'h10 + i * 3);

	// ---- ioctl loader: a write per byte; nothing while it is off ----
	w0 = w_n;
	frame(8'h53, 8'h00, 8'h77);
	burst(8'h53, 32'h00000000, 4, 8'h00, 8'h01);
	if (w_n != w0) fail("ioctl writes while IOCTL_ACTIVE = 0");
	frame(8'h55, 8'h00, 8'h01);
	if (ioctl_active !== 1'b1) fail("IOCTL_ACTIVE");
	frame(8'h52, 8'h00, 8'h00);
	frame(8'h52, 8'h01, 8'h00);
	frame(8'h52, 8'h02, 8'h00);
	frame(8'h53, 8'h00, 8'h61);
	frame(8'h53, 8'h01, 8'h62);
	frame(8'h53, 8'h01, 8'h63); // the same offset: written again
	frame(8'h53, 8'h00, 8'h64); // the file again from offset 0
	burst(8'h53, 32'h00000100, 16, 8'h80, 8'h01);
	frame(8'h55, 8'h00, 8'h00);
	if (ioctl_active !== 1'b0) fail("IOCTL_ACTIVE off");
	if (w_n - w0 != 20) begin
		$display("%t ERROR: ioctl %0d writes, expected 20", $time, w_n - w0);
		errors = errors + 1;
	end
	if (wlog[w0] !== 40'h00000000_61 || wlog[w0 + 1] !== 40'h00000001_62 ||
	    wlog[w0 + 2] !== 40'h00000001_63 || wlog[w0 + 3] !== 40'h00000000_64) fail("ioctl classic writes");
	for (i = 0; i < 16 && i + 4 < w_n - w0; i = i + 1)
		expect_write(w0 + 4 + i, 32'h00000100 + i, 8'h80 + i);

	// ---- spikes on MCU_SS during bursts: no reply word lost ----
	frame(8'h08, 8'h00, 8'h01);
	w0 = w_n;
	uart_tx(8'h51);
	uart_tx(8'h52);
	uart_tx(8'h53);
	spikes = 1'b1;
	for (i = 0; i < 4; i = i + 1) burst(8'h07, 32'h00200000 + i * 64, 64, i * 64, 8'h01);
	spikes = 1'b0;
	frame(8'h08, 8'h00, 8'h00);
	if (w_n - w0 != 256) begin
		$display("%t ERROR: bursts with spikes: %0d writes, expected 256", $time, w_n - w0);
		errors = errors + 1;
	end
	for (i = 0; i < 256 && i < w_n - w0; i = i + 1)
		expect_write(w0 + i, 32'h00200000 + i, i);
	expect_reply(24'hFC_00_51);
	expect_reply(24'hFC_00_52);
	expect_reply(24'hFC_00_53);
	expect_no_reply;

	// ---- FT812 and SD2 chip selects ----
	#1;
	if (miso !== 1'b1) fail("MISO idle");
	ft_ss = 1'b0; ft_miso = 1'b0; sck = 1'b1; mosi = 1'b0;
	#1;
	if (miso !== 1'b0 || ft_cs_n !== 1'b0 || ft_sck !== 1'b1 || ft_mosi !== 1'b0) fail("FT812 pass-through");
	ft_ss = 1'b1; sd2_ss = 1'b0; sd2_miso = 1'b0; sck = 1'b0; mosi = 1'b1;
	#1;
	if (miso !== 1'b0 || sd2_cs_n !== 1'b0 || sd2_sck !== 1'b0 || sd2_mosi !== 1'b1 || ft_cs_n !== 1'b1) fail("SD2 pass-through");
	sd2_miso = 1'b1;
	#1;
	if (miso !== 1'b1) fail("SD2 MISO");
	sd2_ss = 1'b1;
	#FRAME_GAP;

	// ---- N_RESET empties the queue ----
	uart_tx(8'h61);
	uart_tx(8'h62);
	@(negedge clk);
	n_reset = 1'b0;
	@(negedge clk);
	n_reset = 1'b1;
	// the word that was already in the slave's register still goes out
	for (i = 0; i < 6; i = i + 1) frame(8'hFF, 8'h00, 8'h00);
	if (rx_n - rx_rd > 1) fail("queue not emptied by N_RESET");
	rx_rd = rx_n;
	frame(8'hF7, 8'h00, 8'h00);
	expect_reply(24'hF7_03_20);
	expect_no_reply;

	$display("tb_mcu: %0d frames", frames);
	$display("tb_mcu: %0d errors", errors);
	$finish;
end

initial begin
	#100000000;
	$display("ERROR: timeout");
	$display("tb_mcu: 1 errors");
	$finish;
end

endmodule
