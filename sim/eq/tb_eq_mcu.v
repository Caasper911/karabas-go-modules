`timescale 1ns / 1ps

// mcu.vhd (karabas-go-core-nanomig) against kg_mcu.v with the nanomig configuration (CS_FILTER 0:
// nanomig filters the chip selects in its top), ISim: random frames of every command, bursts of
// every type with spikes on MCU_SS, CAPS queries, and on the core side rtc writes, uart bytes,
// matrix words, file mounter words (held until ack), the FT812 / SD2 chip selects, N_RESET now
// and then. Every common output compared after every clock, MISO also at every sck edge.
// Ends with "tb_eq_mcu: N errors".

module tb_eq_mcu;

parameter STEPS = 6000;
`include "eq_check.vh"

reg clk = 1'b0;
always #17.65 clk = ~clk;

reg n_reset = 1'b1;
reg cs_n = 1'b1, sck = 1'b0, mosi = 1'b0, burst_cs_n = 1'b1;
reg ft_ss = 1'b1, sd2_ss = 1'b1, ft_miso = 1'b1, sd2_miso = 1'b1;
reg [7:0] rtc_a = 8'h00, rtc_di = 8'h00;
reg rtc_cs = 1'b0, rtc_wr_n = 1'b1;
reg [7:0] uart_tx_data = 8'h00;
reg uart_tx_wr = 1'b0;
reg [23:0] matrix_cmd = 24'h0;
reg matrix_cmd_wr = 1'b0;
reg img_q_wr = 1'b0;
reg [23:0] img_q_di = 24'h0;

`define OUTS(p) \
	wire p``miso, p``burst_ready, p``ms_upd, p``romloader_active, p``romload_wr, p``ioctl_active; \
	wire p``ft_spi_on, p``ft_vga_on, p``ft_sck, p``ft_mosi, p``ft_cs_n, p``sd2_sck, p``sd2_mosi, p``sd2_cs_n; \
	wire p``dvi_only, p``img_data_wr, p``img_result_wr, p``img_q_ack, p``img_phys_wr, p``busy; \
	wire [7:0] p``ms_x, p``ms_y, p``kb_status, p``kb0, p``kb1, p``kb2, p``kb3, p``kb4, p``kb5; \
	wire [7:0] p``rtc_do, p``uart_rx_data, p``uart_rx_idx, p``romload_data, p``hwid, p``img_mounted, p``img_data, p``img_result; \
	wire [3:0] p``ms_z; \
	wire [2:0] p``ms_b; \
	wire [12:0] p``joy_l, p``joy_r; \
	wire [1:0] p``btns; \
	wire [15:0] p``softsw, p``osd, p``img_sum, p``img_phys; \
	wire [31:0] p``romload_addr; \
	wire [63:0] p``img_size; \
	wire [8:0] p``img_data_addr;
`OUTS(o_)
`OUTS(n_)

`define PORTS(p) \
	.CLK(clk), .N_RESET(n_reset), \
	.MCU_MOSI(mosi), .MCU_MISO(p``miso), .MCU_SCK(sck), .MCU_SS(cs_n), \
	.MCU_SPI_FT_SS(ft_ss), .MCU_SPI_SD2_SS(sd2_ss), .MCU_BURST_CS_N(burst_cs_n), .MCU_BURST_READY(p``burst_ready), \
	.MS_X(p``ms_x), .MS_Y(p``ms_y), .MS_B(p``ms_b), .MS_Z(p``ms_z), .MS_UPD(p``ms_upd), \
	.KB_STATUS(p``kb_status), .KB_DAT0(p``kb0), .KB_DAT1(p``kb1), .KB_DAT2(p``kb2), .KB_DAT3(p``kb3), .KB_DAT4(p``kb4), .KB_DAT5(p``kb5), \
	.JOY_L(p``joy_l), .JOY_R(p``joy_r), .BTNS(p``btns), \
	.RTC_A(rtc_a), .RTC_DI(rtc_di), .RTC_DO(p``rtc_do), .RTC_CS(rtc_cs), .RTC_WR_N(rtc_wr_n), \
	.UART_RX_DATA(p``uart_rx_data), .UART_RX_IDX(p``uart_rx_idx), .UART_TX_DATA(uart_tx_data), .UART_TX_WR(uart_tx_wr), \
	.SOFTSW_COMMAND(p``softsw), \
	.ROMLOADER_ACTIVE(p``romloader_active), .ROMLOAD_ADDR(p``romload_addr), .ROMLOAD_DATA(p``romload_data), \
	.ROMLOAD_WR(p``romload_wr), .IOCTL_ACTIVE(p``ioctl_active), \
	.OSD_COMMAND(p``osd), \
	.FT_SPI_ON(p``ft_spi_on), .FT_VGA_ON(p``ft_vga_on), \
	.FT_SCK(p``ft_sck), .FT_MOSI(p``ft_mosi), .FT_MISO(ft_miso), .FT_CS_N(p``ft_cs_n), \
	.SD2_SCK(p``sd2_sck), .SD2_MOSI(p``sd2_mosi), .SD2_MISO(sd2_miso), .SD2_CS_N(p``sd2_cs_n), \
	.MATRIX_CMD(matrix_cmd), .MATRIX_CMD_WR(matrix_cmd_wr), \
	.HWID(p``hwid), .DVI_ONLY(p``dvi_only), \
	.IMG_MOUNTED(p``img_mounted), .IMG_SIZE(p``img_size), .IMG_DATA_WR(p``img_data_wr), .IMG_DATA_ADDR(p``img_data_addr), \
	.IMG_DATA(p``img_data), .IMG_RESULT_WR(p``img_result_wr), .IMG_RESULT(p``img_result), .IMG_SUM(p``img_sum), \
	.IMG_Q_WR(img_q_wr), .IMG_Q_DI(img_q_di), .IMG_Q_ACK(p``img_q_ack), \
	.IMG_PHYS_WR(p``img_phys_wr), .IMG_PHYS(p``img_phys), \
	.BUSY(p``busy)

mcu #(.BURST_MAX_MHZ(32)) old_dut(`PORTS(o_));

kg_mcu #(.BURST_MAX_MHZ(32), .CS_FILTER(0), .ENABLE_IMG(1), .ENABLE_DEBUG(0), .ENABLE_FILE(1),
	.FILE_CMDS(0), .FILE_WR_EACH(1), .FILE_TO_ROM(1)) new_dut(`PORTS(n_),
	.KB_SCANCODE(), .KB_SCANCODE_UPD(), .XT_SCANCODE(), .XT_SCANCODE_UPD(),
	.UART_TX_MODE(1'b0), .UART_DLM(8'h00), .UART_DLL(8'h00), .UART_DLM_WR(1'b0), .UART_DLL_WR(1'b0),
	.FILELOAD_RESET(), .FILELOAD_ACTIVE(), .FILELOAD_SIZE(), .FILELOAD_ADDR(), .FILELOAD_DATA(), .FILELOAD_WR(),
	.FT_RESET(), .DEBUG_ADDR(16'h0000), .DEBUG_DATA(16'h0000));

`define C(name) eq_check(`"name`", o_``name, n_``name);
task automatic compare;
	begin
		`C(miso) `C(burst_ready) `C(ms_upd) `C(romloader_active) `C(romload_wr) `C(ioctl_active)
		`C(ft_spi_on) `C(ft_vga_on) `C(ft_sck) `C(ft_mosi) `C(ft_cs_n) `C(sd2_sck) `C(sd2_mosi) `C(sd2_cs_n)
		`C(dvi_only) `C(img_data_wr) `C(img_result_wr) `C(img_q_ack) `C(img_phys_wr) `C(busy)
		`C(ms_x) `C(ms_y) `C(kb_status) `C(kb0) `C(kb1) `C(kb2) `C(kb3) `C(kb4) `C(kb5)
		if (!rtc_coll) `C(rtc_do)
		`C(uart_rx_data) `C(uart_rx_idx) `C(romload_data) `C(hwid) `C(img_mounted) `C(img_data) `C(img_result)
		`C(ms_z) `C(ms_b) `C(joy_l) `C(joy_r) `C(btns) `C(softsw) `C(osd) `C(img_sum) `C(img_phys)
		`C(romload_addr) `C(img_size) `C(img_data_addr)
	end
endtask
// the rtc RAM written at the address read in the same clock: undefined on the FPGA (dpram_sim
// gives the new word, kg_sdpram the old one), rtc_do not compared after it
reg rtc_coll = 1'b0;
always @(posedge clk)
	rtc_coll <= new_dut.kg_mcu_rtc_on.u_rtc.w && new_dut.kg_mcu_rtc_on.u_rtc.wa == rtc_a;
always @(negedge clk) compare;
always @(sck) #1 eq_check("miso (sck)", o_miso, n_miso);

// ---------------- mcu side ----------------

integer seed = 31, half = 31;
reg [7:0] dummy;
integer frames = 0, bursts = 0, replies = 0;

task spi_byte(input [7:0] tx);
	integer k;
	begin
		for (k = 7; k >= 0; k = k - 1) begin
			mosi = tx[k];
			#(half);
			sck = 1'b1;
			#(half);
			sck = 1'b0;
		end
	end
endtask

// commands, with the addresses they use
reg [7:0] cmds [0:27];
initial begin
	cmds[0] = 8'h01; cmds[1] = 8'h02; cmds[2] = 8'h03; cmds[3] = 8'h04; cmds[4] = 8'h05; cmds[5] = 8'h06;
	cmds[6] = 8'h07; cmds[7] = 8'h08; cmds[8] = 8'h09; cmds[9] = 8'h20; cmds[10] = 8'h40; cmds[11] = 8'h41;
	cmds[12] = 8'h42; cmds[13] = 8'h43; cmds[14] = 8'h44; cmds[15] = 8'h45; cmds[16] = 8'h46; cmds[17] = 8'h52;
	cmds[18] = 8'h53; cmds[19] = 8'h55; cmds[20] = 8'hF7; cmds[21] = 8'hF9; cmds[22] = 8'hFA; cmds[23] = 8'hFC;
	cmds[24] = 8'hFD; cmds[25] = 8'hFE; cmds[26] = 8'hFF; cmds[27] = 8'h0B;
end

task frame(input [7:0] c, input [7:0] a, input [7:0] d);
	begin
		cs_n = 1'b0;
		#(60 + ($random(seed) & 63));
		spi_byte(c);
		spi_byte(a);
		spi_byte(d);
		#(30 + ($random(seed) & 31));
		cs_n = 1'b1;
		frames = frames + 1;
		#(400 + ($random(seed) & 1023));
	end
endtask

reg spikes = 1'b0, spike_go = 1'b0;
always @(posedge spike_go) begin
	#(half * 13 / 2);
	cs_n = 1'b0;
	#110;
	cs_n = 1'b1;
end

task burst(input [7:0] t, input [31:0] addr, input integer n);
	integer k;
	begin
		burst_cs_n = 1'b0;
		#(60 + ($random(seed) & 31));
		spi_byte(t);
		spi_byte(addr[31:24]);
		spi_byte(addr[23:16]);
		spi_byte(addr[15:8]);
		spi_byte(addr[7:0]);
		for (k = 0; k < n; k = k + 1) begin
			spike_go = spikes && ($random(seed) & 7) == 0;
			spi_byte($random(seed));
			if (spike_go) #200;
			spike_go = 1'b0;
		end
		#(60 + ($random(seed) & 31));
		burst_cs_n = 1'b1;
		bursts = bursts + 1;
		#(400 + ($random(seed) & 1023));
	end
endtask

// ---------------- core side ----------------

reg [31:0] rc;
always @(negedge clk) begin
	rc = $random(seed);
	// rtc writes of the core (also of registers C, D and while busy)
	// (about a word per 400 clocks in all: a frame takes one about every 85)
	rtc_cs <= rc[9:0] == 0;
	rtc_wr_n <= !(rc[9:0] == 0);
	rtc_a <= rc[10] ? { 4'h0, rc[14:11] } : rc[31:24]; // half of them 0-F (C and D often)
	rtc_di <= rc[23:16];
	// uart bytes, matrix words
	uart_tx_wr <= rc[9:0] == 1;
	uart_tx_data <= rc[15:8];
	matrix_cmd_wr <= rc[9:0] == 2 || rc[9:0] == 3 || rc[9:0] == 1; // also with a uart byte
	matrix_cmd <= { 8'h70, rc[31:16] };
	// FT812 / SD2
	if (rc[15:4] == 0) ft_ss <= ~ft_ss;
	if (rc[15:4] == 1) sd2_ss <= ~sd2_ss;
	ft_miso <= rc[13];
	sd2_miso <= rc[14];
end

// file mounter words: held until ack, now and then the next one right after. Not faster: the
// queue must not fill, kg_fifo holds 512 words, fifo.v 511 (tb_mcu tests a full queue)
always @(negedge clk) begin
	if (o_img_q_ack) begin
		img_q_di <= $random(seed);
		img_q_wr <= ($random(seed) & 15) == 0;
	end
	else if (!img_q_wr && ($random(seed) & 255) == 0) begin
		img_q_di <= $random(seed);
		img_q_wr <= 1'b1;
	end
end

integer max_level = 0;
always @(posedge clk)
	if (new_dut.u_link.u_queue.count > max_level) max_level = new_dut.u_link.u_queue.count;

// ---------------- test ----------------

integer s;
reg [31:0] r;
initial begin
	#500;
	// the bank bytes of mcu.vhd have no initial value (0 on the FPGA, U in ISim, and an address
	// compare with U is false): set them first
	frame(8'h06, 8'h00, 8'h00);
	frame(8'h06, 8'h01, 8'h00);
	frame(8'h06, 8'h02, 8'h00);
	for (s = 0; s < STEPS; s = s + 1) begin
		r = $random(seed);
		half = 20 + r[5:0] % 20;
		case (r[9:7])
			3'd0, 3'd1, 3'd2, 3'd3:
				frame(cmds[r[14:10] % 28], (r[15] ? r[18:16] : r[23:16]), r[31:24]);
			3'd4: begin // a burst
				half = 16 + r[3:0] % 8;
				spikes = r[10];
				case (r[12:11])
					2'd0: burst(8'h07, $random(seed), 1 + r[20:16]);
					2'd1: burst(8'h53, $random(seed), 1 + r[20:16]);
					2'd2: burst(8'h45, $random(seed), 1 + r[20:16]);
					2'd3: burst(r[31:24], $random(seed), 1 + r[20:16]);
				endcase
				spikes = 1'b0;
			end
			3'd5: frame(8'hF7, 8'h00, 8'h00);  // CAPS
			3'd6: begin                        // loaders on / off
				frame(8'h08, 8'h00, r[16]);
				frame(8'h55, 8'h00, r[17]);
			end
			3'd7:
				if (r[20:16] == 0) begin       // a reset of the queue
					@(negedge clk);
					n_reset = 1'b0;
					@(negedge clk);
					n_reset = 1'b1;
				end
				else
					frame(8'hFF, 8'h00, 8'h00);
		endcase
	end
	#2000;
	if (max_level > 400) begin
		$display("ERROR: the queue reached %0d words", max_level);
		errors = errors + 1;
	end
	$display("tb_eq_mcu: %0d frames, %0d bursts, %0d checks, queue up to %0d words", frames, bursts, checks, max_level);
	$display("tb_eq_mcu: %0d errors", errors);
	$finish;
end

endmodule
