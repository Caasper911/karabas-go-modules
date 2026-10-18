-------------------------------------------------------------------------------
-- MCU SPI comm module
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.conv_integer;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity mcu is
	generic (
		-- highest burst SCK announced to the mcu in the CMD_CAPS answer, MHz (0 = normal link
		-- clock, 16 MHz). Raise it only on boards where bursts were verified at that clock.
		BURST_MAX_MHZ : integer := 0
	);
	port
	(
	 CLK			 : in std_logic;
	 N_RESET 	 : in std_logic := '1';

	 -- spi
    MCU_MOSI    : in std_logic;
    MCU_MISO    : out std_logic := 'Z';
    MCU_SCK     : in std_logic;
	 MCU_SS 		 : in std_logic;
	 MCU_SPI_FT_SS 		 : in std_logic;
	 MCU_SPI_SD2_SS 		 : in std_logic;	 

	 -- burst transfers (karabas-go-firmware docs/burst_protocol.md)
	 MCU_BURST_CS_N  : in std_logic := '1';
	 MCU_BURST_READY : out std_logic := '1';

	 -- usb mouse
	 MS_X 	 	: out std_logic_vector(7 downto 0) := "00000000";
	 MS_Y 	 	: out std_logic_vector(7 downto 0) := "00000000";
	 MS_B 	   : out std_logic_vector(2 downto 0) := "000";
	 MS_Z 		: out std_logic_vector(3 downto 0) := "0000";
	 MS_UPD		: buffer std_logic := '0'; -- todo: refactor it, move ms event to abs coord into a new module "cursor"
	 
	 -- usb keyboard
	 KB_STATUS : out std_logic_vector(7 downto 0) := "00000000";
	 KB_DAT0   : out std_logic_vector(7 downto 0) := "00000000";
	 KB_DAT1   : out std_logic_vector(7 downto 0) := "00000000";
	 KB_DAT2   : out std_logic_vector(7 downto 0) := "00000000";
	 KB_DAT3   : out std_logic_vector(7 downto 0) := "00000000";
	 KB_DAT4   : out std_logic_vector(7 downto 0) := "00000000";
	 KB_DAT5   : out std_logic_vector(7 downto 0) := "00000000";

	 -- joysticks
	 JOY_L			: out std_logic_vector(12 downto 0) := (others => '0');
	 JOY_R			: out std_logic_vector(12 downto 0) := (others => '0');
	 
	 -- hw buttons
	 BTNS 			: out std_logic_vector(1 downto 0) := "00";

    -- rtc	 
	 RTC_A 		: in std_logic_vector(7 downto 0);
	 RTC_DI 		: in std_logic_vector(7 downto 0);
	 RTC_DO 		: out std_logic_vector(7 downto 0);
	 RTC_CS 		: in std_logic := '0';
	 RTC_WR_N 	: in std_logic := '1';
	 
	 -- usb uart
	 UART_RX_DATA			: out std_logic_vector(7 downto 0);
	 UART_RX_IDX	: out std_logic_vector(7 downto 0) := (others => '0');
	 
	 UART_TX_DATA			: in std_logic_vector(7 downto 0);
	 UART_TX_WR				: in std_logic := '0';
	 
	 -- soft switches command
	 SOFTSW_COMMAND : out std_logic_vector(15 downto 0);
	 
	 -- rom loader
	 ROMLOADER_ACTIVE : buffer std_logic := '0';
	 ROMLOAD_ADDR: buffer std_logic_vector(31 downto 0) := x"FFFFFFFF";
	 ROMLOAD_DATA: out std_logic_vector(7 downto 0) := (others => '0');
	 ROMLOAD_WR : out std_logic := '0';
	 -- karabas: the ioctl file loader (FL osd items) writes through the same ROMLOAD_* signals,
	 -- with the file offset as ROMLOAD_ADDR; the slot, size and extension are not used
	 IOCTL_ACTIVE : buffer std_logic := '0';

    -- osd command
	 OSD_COMMAND: out std_logic_vector(15 downto 0);
	 
	 -- ft812 exclusive access by mcu
	 FT_SPI_ON : buffer std_logic := '0'; -- spi access on
	 FT_VGA_ON : buffer std_logic := '0'; -- vga access on

	 FT_SCK	  : out std_logic := '1';
	 FT_MOSI	  : out std_logic := '1';
	 FT_MISO	  : in  std_logic := '1';
	 FT_CS_N   : out std_logic := '1';
	 
	 -- sd2 exclusive access by mcu
	 SD2_SCK	  : out std_logic := '1';
	 SD2_MOSI	  : out std_logic := '1';
	 SD2_MISO	  : in  std_logic := '1';
	 SD2_CS_N   : out std_logic := '1';	 
	 
	 -- dot matrix
	 MATRIX_CMD : in std_logic_vector(23 downto 0) := (others => '0');
	 MATRIX_CMD_WR : in std_logic := '0';

	 -- hw setup
	 HWID : out std_logic_vector(7 downto 0) := (others => '0');
	 DVI_ONLY : out std_logic := '0';
	 
	 -- file mounter (karabas-go-firmware docs/protocol.md, IMG_* commands)
	 IMG_MOUNTED   : out std_logic_vector(7 downto 0) := (others => '0'); -- one clock: new IMG_SIZE of the slot
	 IMG_SIZE      : out std_logic_vector(63 downto 0) := (others => '0');
	 IMG_DATA_WR   : out std_logic := '0'; -- one clock: a byte of the sector read
	 IMG_DATA_ADDR : out std_logic_vector(8 downto 0) := (others => '0');
	 IMG_DATA      : out std_logic_vector(7 downto 0) := (others => '0');
	 IMG_RESULT_WR : out std_logic := '0'; -- one clock: end of a request
	 IMG_RESULT    : out std_logic_vector(7 downto 0) := (others => '0'); -- 1 done, 2 error
	 IMG_SUM       : out std_logic_vector(15 downto 0) := (others => '0'); -- 16-bit sum of the sector read
	 IMG_Q_WR      : in std_logic := '0'; -- a frame to the mcu (request, write data), held until IMG_Q_ACK
	 IMG_Q_DI      : in std_logic_vector(23 downto 0) := (others => '0');
	 IMG_Q_ACK     : buffer std_logic := '0';
	 IMG_PHYS_WR   : out std_logic := '0'; -- one clock: a slot was set to a physical drive (CMD_IMG_PHYS)
	 IMG_PHYS      : out std_logic_vector(15 downto 0) := (others => '0'); -- slot & drive (0 none, 1 DS0, 2 DS1)

	 -- busy
	 BUSY: buffer std_logic := '1'
	 
	);
    end mcu;
architecture rtl of mcu is

	-- spi commands
	constant CMD_KBD			: std_logic_vector(7 downto 0) := x"01";
	constant CMD_MOUSE 		: std_logic_vector(7 downto 0) := x"02";
	constant CMD_JOY   		: std_logic_vector(7 downto 0) := x"03";
	constant CMD_BTNS			: std_logic_vector(7 downto 0) := x"04";
	constant CMD_SWITCHES   : std_logic_vector(7 downto 0) := x"05";
	constant CMD_ROMBANK    : std_logic_vector(7 downto 0) := x"06";
	constant CMD_ROMDATA    : std_logic_vector(7 downto 0) := x"07";
	constant CMD_ROMLOADER  : std_logic_vector(7 downto 0) := x"08";
	constant CMD_CONTROL    : std_logic_vector(7 downto 0) := x"09";

	-- 11, 12 - usb gamepad, joy : todo

	constant CMD_OSD 			: std_logic_vector(7 downto 0) := x"20";
	constant CMD_IMG_SLOT     : std_logic_vector(7 downto 0) := x"40";
	constant CMD_IMG_SIZE     : std_logic_vector(7 downto 0) := x"41";
	constant CMD_IMG_LBA      : std_logic_vector(7 downto 0) := x"42";
	constant CMD_IMG_SEC      : std_logic_vector(7 downto 0) := x"43";
	constant CMD_IMG_BUF_BANK : std_logic_vector(7 downto 0) := x"44";
	constant CMD_IMG_BUF_DATA : std_logic_vector(7 downto 0) := x"45";
	constant CMD_IMG_PHYS     : std_logic_vector(7 downto 0) := x"46";
	constant CMD_IOCTL_BANK   : std_logic_vector(7 downto 0) := x"52";
	constant CMD_IOCTL_DATA   : std_logic_vector(7 downto 0) := x"53";
	constant CMD_IOCTL_STATE  : std_logic_vector(7 downto 0) := x"55";
	constant CMD_CAPS		: std_logic_vector(7 downto 0) := x"F7";
	constant CMD_HW_SETUP	: std_logic_vector(7 downto 0) := x"F9";
	constant CMD_RTC 			: std_logic_vector(7 downto 0) := x"FA";
	constant CMD_FLASHBOOT  : std_logic_vector(7 downto 0) := x"FB";
	constant CMD_UART			: std_logic_vector(7 downto 0) := x"FC";
	constant CMD_INIT_START	: std_logic_vector(7 downto 0) := x"FD";
	constant CMD_INIT_DONE	: std_logic_vector(7 downto 0) := x"FE";	
	constant CMD_NOPE			: std_logic_vector(7 downto 0) := x"FF";

	 -- spi
	 signal spi_do_valid 	: std_logic := '0';
	 signal prev_spi_do_valid : std_logic := '0';
	 signal spi_di 			: std_logic_vector(23 downto 0);
	 signal spi_do 			: std_logic_vector(23 downto 0);
	 signal spi_miso 		 	: std_logic;
	 
	 -- rtc 2-port ram signals
	 signal rtcw_di 			: std_logic_vector(7 downto 0);
	 signal rtcw_a 			: std_logic_vector(7 downto 0);
	 signal rtcw_wr 			: std_logic := '0';
	 signal rtcr_do 			: std_logic_vector(7 downto 0);

	-- rtc data from mcu
	 signal rtcr_a 			: std_logic_vector(7 downto 0);
	 signal rtcr_d 			: std_logic_vector(7 downto 0);
	 signal last_rtcr_a 		: std_logic_vector(7 downto 0);
	 signal last_rtcr_d 		: std_logic_vector(7 downto 0);
	 signal rtcr_command    : std_logic := '0';
	 signal last_rtcr_command : std_logic := '0';
	 
	 -- romload addr
	 signal tmp_romload_addr    : std_logic_vector(31 downto 0);
	 signal prev_romload_addr   : std_logic_vector(31 downto 0) := x"FFFFFFFF";
	 signal ioctl_wr            : std_logic := '0';
	 
	-- spi fifo 
	signal queue_di			: std_logic_vector(23 downto 0);
	signal queue_wr_req		: std_logic := '0';
	signal queue_wr_full		: std_logic;
		
	signal queue_rd_req		: std_logic := '0';
	signal queue_do			: std_logic_vector(23 downto 0);
	signal queue_rd_empty   : std_logic;
	
	signal queue_data_count : std_logic_vector(8 downto 0) := (others => '0');
	
	--state machine for queue writes
	type qmachine IS(idle, rtc_wr_req, rtc_wr_ack);
	signal qstate : qmachine := idle;

	-- capabilities answered to the CMD_CAPS query:
	-- bit 0 = burst write, bit 1 = MCU_BURST_READY is driven; max burst SCK from BURST_MAX_MHZ
	constant CAPS           : std_logic_vector(7 downto 0) := x"03";
	constant CAPS_MAX_MHZ   : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(BURST_MAX_MHZ, 8));
	signal caps_req         : std_logic := '0';
	signal caps_ack         : std_logic := '0';

	-- burst receiver
	signal burst_type       : std_logic_vector(7 downto 0);
	signal burst_addr       : std_logic_vector(31 downto 0);
	signal burst_data       : std_logic_vector(7 downto 0);
	signal burst_wr         : std_logic;

	-- file mounter
	signal img_slot         : std_logic_vector(7 downto 0) := (others => '0');
	signal img_size_tmp     : std_logic_vector(63 downto 0) := (others => '0');
	signal img_bank         : std_logic_vector(7 downto 0) := (others => '0');
	signal spi_ssel         : std_logic;
		 
begin
	
	--------------------------------------------------------------------------
	-- MCU SPI communication
	--------------------------------------------------------------------------		  
	
	U_SPI: entity work.spi_slave
	generic map(
			N             => 24 -- 3 bytes (cmd + addr + data)       
	 )
	port map(
		  clk_i          => CLK,
		  spi_sck_i      => MCU_SCK,
		  spi_ssel_i     => spi_ssel,
		  spi_mosi_i     => MCU_MOSI,
		  spi_miso_o     => spi_miso,

		  di_req_o       => open,
		  di_i           => spi_di,
		  wren_i         => '1',
		  
		  do_valid_o     => spi_do_valid,
		  do_o           => spi_do,

		  do_transfer_o  => open,
		  wren_o         => open,
		  wren_ack_o     => open,
		  rx_bit_reg_o   => open,
		  state_dbg_o    => open
	);

	spi_di <= queue_do; -- when queue_rd_empty = '0' else x"FFFFFF";

	-- karabas: the classic slave is not selected during a burst. sck runs for the burst, and a
	-- short spike on MCU_SS (Mini G) let the slave shift and take a reply word that never went out.
	spi_ssel <= MCU_SS or not MCU_BURST_CS_N;

	--------------------------------------------------------------------------
	-- MCU burst transfers (second chip select, see docs/burst_protocol.md)
	--------------------------------------------------------------------------

	U_BURST: entity work.burst_rx
	port map(
		CLK      => CLK,
		SCK      => MCU_SCK,
		MOSI     => MCU_MOSI,
		CS_N     => MCU_BURST_CS_N,
		TYPE_O   => burst_type,
		ADDR_O   => burst_addr,
		DATA_O   => burst_data,
		WR_O     => burst_wr,
		ACTIVE_O => open
	);

	-- a burst byte arrives every 250 ns at most (32 MHz SCK). The loader writes a byte to SRAM
	-- in one clock and to the GS SDRAM in about 12 clk_sdr cycles (~145 ns), so a whole burst
	-- can always be accepted. A core with a slower consumer puts a fifo here and drops READY
	-- while it has less than 512 bytes free.
	MCU_BURST_READY <= '1';
--	queue_rd_req <= spi_di_req;
	
	MCU_MISO <= 
		spi_miso when spi_ssel = '0' else 
		SD2_MISO when MCU_SPI_SD2_SS = '0' else
		FT_MISO when MCU_SPI_FT_SS = '0' else 
		'1';		
	
	FT_SCK <= MCU_SCK;
	FT_CS_N <= MCU_SPI_FT_SS;
	FT_MOSI <= MCU_MOSI;
	
	SD2_SCK <= MCU_SCK;
	SD2_CS_N <= MCU_SPI_SD2_SS;
	SD2_MOSI <= MCU_MOSI;	
	
	-- pull queue data
	-- karabas: one word per received frame, on do_valid. di_req of spi_slave is a combinational
	-- decode of its sck-domain state (states 4 to 1, 4 -> 3 flips three bits), sampled here
	-- without a synchroniser: a glitch gave a second request in a complete frame, and a reply
	-- word was lost (hardware: 3-9 pops more than frames per ~1000 frames). do_valid comes from
	-- a register. The word popped after frame k is sent in frame k+1, as before: the fifo
	-- output is in di_reg about 7 clocks (250 ns) after the frame, the mcu waits >= 4.5 us.
	process (CLK)
	begin 
		if rising_edge(CLK) then 
			queue_rd_req <= '0';
			if (spi_do_valid = '1' and prev_spi_do_valid = '0') then 
				queue_rd_req <= '1';
			end if;
		end if;
	end process;

	process (CLK, spi_do_valid, spi_do, prev_spi_do_valid)
	begin
		if (rising_edge(CLK)) then
			IMG_MOUNTED <= (others => '0');
			IMG_PHYS_WR <= '0';
			IMG_DATA_WR <= '0';
			IMG_RESULT_WR <= '0';
			ioctl_wr <= '0';
			prev_spi_do_valid <= spi_do_valid;
			if spi_do_valid = '1' and prev_spi_do_valid = '0' then
				case spi_do(23 downto 16) is 
					-- keyboard
					when CMD_KBD => 
						case spi_do(15 downto 8) is 
							when X"00" => kb_status <= spi_do(7 downto 0);
							when X"01" => kb_dat0 <= spi_do(7 downto 0);
							when X"02" => kb_dat1 <= spi_do(7 downto 0);
							when X"03" => kb_dat2 <= spi_do(7 downto 0);
							when X"04" => kb_dat3 <= spi_do(7 downto 0);
							when X"05" => kb_dat4 <= spi_do(7 downto 0);
							when X"06" => kb_dat5 <= spi_do(7 downto 0);
							when others => null;
						end case;
					-- mouse data
					when CMD_MOUSE => 
						case spi_do(15 downto 8) is
							when X"00" => MS_X(7 downto 0) <= spi_do(7 downto 0);
							when X"01" => MS_Y(7 downto 0) <= spi_do(7 downto 0);
							when X"02" => MS_Z(3 downto 0) <= spi_do(3 downto 0);
							when X"03" => MS_B(2 downto 0) <= spi_do(2 downto 0); MS_UPD <= not(MS_UPD);
							when others => null;
						end case;
					-- joy data
					when CMD_JOY => 
						case spi_do(15 downto 8) is
							-- joy L
							when x"00" =>
									  joy_l(0) <= spi_do(0); -- ON
									  joy_l(1) <= spi_do(1); -- UP 
									  joy_l(2) <= spi_do(2); -- DOWN 
									  joy_l(3) <= spi_do(3); -- LEFT
									  joy_l(4) <= spi_do(4); -- RIGHT
									  joy_l(5) <= spi_do(5); -- START
									  joy_l(6) <= spi_do(6); -- A
									  joy_l(7) <= spi_do(7); -- B
							when x"01" =>
									  joy_l(8) <= spi_do(0); -- C 
									  joy_l(9) <= spi_do(1); -- X 
									  joy_l(10) <= spi_do(2); -- Y 
									  joy_l(11) <= spi_do(3); -- Z
									  joy_l(12) <= spi_do(4); -- MODE

							-- joy R
							when x"02" =>
									  joy_r(0) <= spi_do(0); -- ON
									  joy_r(1) <= spi_do(1); -- UP 
									  joy_r(2) <= spi_do(2); -- DOWN 
									  joy_r(3) <= spi_do(3); -- LEFT
									  joy_r(4) <= spi_do(4); -- RIGHT
									  joy_r(5) <= spi_do(5); -- START
									  joy_r(6) <= spi_do(6); -- A
									  joy_r(7) <= spi_do(7); -- B
							when x"03" =>
									  joy_r(8) <= spi_do(0); -- C 
									  joy_r(9) <= spi_do(1); -- X 
									  joy_r(10) <= spi_do(2); -- Y 
									  joy_r(11) <= spi_do(3); -- Z
									  joy_r(12) <= spi_do(4); -- MODE
							when others => null;
						end case;

					-- hw buttons
					when CMD_BTNS => 
						case spi_do(15 downto 8) is
							when x"00" => BTNS(0) <= spi_do(0);
							when x"01" => BTNS(1) <= spi_do(0);
							when others => null;
						end case;

					-- soft switches
					when CMD_SWITCHES => SOFTSW_COMMAND <= spi_do(15 downto 0);
							
					-- osd commands					
					when CMD_OSD => OSD_COMMAND <= spi_do(15 downto 0);
					
					-- rombank (and the ioctl bank: the same address bytes)
					when CMD_ROMBANK | CMD_IOCTL_BANK => 
						case spi_do(15 downto 8) is
							when x"00" => tmp_romload_addr(15 downto 8) <= spi_do(7 downto 0);
							when x"01" => tmp_romload_addr(23 downto 16) <= spi_do(7 downto 0);
							when x"02" => tmp_romload_addr(31 downto 24) <= spi_do(7 downto 0);
							when others => null;
						end case;
						
					-- romdata (and the ioctl data: the file offset is the address)
					when CMD_ROMDATA | CMD_IOCTL_DATA => 
						ROMLOAD_ADDR(31 downto 8) <= tmp_romload_addr(31 downto 8);
						ROMLOAD_ADDR(7 downto 0) <= spi_do(15 downto 8);
						ROMLOAD_DATA(7 downto 0) <= spi_do(7 downto 0);
						if spi_do(23 downto 16) = CMD_IOCTL_DATA then
							ioctl_wr <= IOCTL_ACTIVE;
						end if;
						
					when CMD_ROMLOADER =>
						ROMLOADER_ACTIVE <= spi_do(0);

					when CMD_IOCTL_STATE =>
						IOCTL_ACTIVE <= spi_do(0);
							
					-- rtc 
					when CMD_RTC =>						
						rtcr_a <= spi_do(15 downto 8);
						rtcr_d <= spi_do(7 downto 0);
						rtcr_command <= not rtcr_command;
						
					-- uart
					when CMD_UART =>
						UART_RX_DATA <= spi_do(7 downto 0);
						UART_RX_IDX <= spi_do(15 downto 8);
						
					-- hw setup
					when CMD_HW_SETUP => 
						case spi_do(15 downto 8) is
							when x"00" => HWID <= spi_do(7 downto 0);
							when x"01" => DVI_ONLY <= spi_do(0);
							when others => null;
						end case;

					-- init start
					when CMD_INIT_START => BUSY <= '1';

					-- init done
					when CMD_INIT_DONE => BUSY <= '0';

					-- ft812 / SD spi control
					when CMD_CONTROL => 
								FT_SPI_ON <= spi_do(0);
								FT_VGA_ON <= spi_do(1);

					-- capability query: answer through the queue to the mcu
					when CMD_CAPS =>
						if spi_do(15 downto 8) = x"00" then
							caps_req <= not caps_req;
						end if;

					-- file mounter: image of a slot (size 0 = none), sector data, result
					when CMD_IMG_SLOT => img_slot <= spi_do(7 downto 0);
					when CMD_IMG_SIZE =>
						case spi_do(15 downto 8) is
							when x"00" => img_size_tmp(7 downto 0) <= spi_do(7 downto 0);
							when x"01" => img_size_tmp(15 downto 8) <= spi_do(7 downto 0);
							when x"02" => img_size_tmp(23 downto 16) <= spi_do(7 downto 0);
							when x"03" => img_size_tmp(31 downto 24) <= spi_do(7 downto 0);
							when x"04" => img_size_tmp(39 downto 32) <= spi_do(7 downto 0);
							when x"05" => img_size_tmp(47 downto 40) <= spi_do(7 downto 0);
							when x"06" => img_size_tmp(55 downto 48) <= spi_do(7 downto 0);
							when x"07" =>
								IMG_SIZE <= spi_do(7 downto 0) & img_size_tmp(55 downto 0);
								IMG_MOUNTED(to_integer(unsigned(img_slot(2 downto 0)))) <= '1';
							when others => null;
						end case;
					when CMD_IMG_PHYS => -- a physical drive for the slot (after its size 0 frames)
						IMG_PHYS <= spi_do(15 downto 0);
						IMG_PHYS_WR <= '1';
					when CMD_IMG_LBA => -- mcu -> fpga: the sum of the sector read, before the result
						case spi_do(15 downto 8) is
							when x"00" => IMG_SUM(7 downto 0) <= spi_do(7 downto 0);
							when x"01" => IMG_SUM(15 downto 8) <= spi_do(7 downto 0);
							when others => null;
						end case;
					when CMD_IMG_SEC =>
						IMG_RESULT <= spi_do(7 downto 0);
						IMG_RESULT_WR <= '1';
					when CMD_IMG_BUF_BANK => img_bank <= spi_do(7 downto 0);
					when CMD_IMG_BUF_DATA =>
						IMG_DATA_ADDR <= img_bank(0) & spi_do(15 downto 8);
						IMG_DATA <= spi_do(7 downto 0);
						IMG_DATA_WR <= '1';

					-- nope
					when CMD_NOPE => null;
					
					when others => null;
				end case;
			end if;

			-- burst data: the same loader signals as the classic bank + data commands
			-- (the write strobes follow the address change below)
			if burst_wr = '1' then
				if burst_type = CMD_ROMDATA or burst_type = CMD_IOCTL_DATA then
					ROMLOAD_ADDR <= burst_addr;
					ROMLOAD_DATA <= burst_data;
				end if;
				if burst_type = CMD_IOCTL_DATA then
					ioctl_wr <= IOCTL_ACTIVE;
				end if;
				if burst_type = CMD_IMG_BUF_DATA then
					IMG_DATA_ADDR <= burst_addr(8 downto 0);
					IMG_DATA <= burst_data;
					IMG_DATA_WR <= '1';
				end if;
			end if;
		end if;
	end process;
	
	-- romload wr signal
	-- karabas: the ioctl loader writes on each data byte (ioctl_wr, one clock after the address):
	-- its file starts again at offset 0, which the address compare could miss. The rom loader
	-- follows the address while it is off, so it does not write the last ioctl byte again.
	process (CLK, ROMLOAD_ADDR, prev_romload_addr, ROMLOADER_ACTIVE)
	begin
		if rising_edge(CLK) then 
			ROMLOAD_WR <= '0';
			if ioctl_wr = '1' then
				ROMLOAD_WR <= '1';
			end if;
			if ROMLOADER_ACTIVE = '0' then
				prev_romload_addr <= ROMLOAD_ADDR;
			elsif (prev_romload_addr /= ROMLOAD_ADDR) then 
				ROMLOAD_WR <= '1';
				prev_romload_addr <= ROMLOAD_ADDR;
			end if;
		end if;
	end process;

	--------------------------------------------------------------------------
	-- mc146818a emulation	
	-- http://web.stanford.edu/class/cs140/projects/pintos/specs/mc146818a.pdf
	--------------------------------------------------------------------------
	-- 
	-- 000000 = 00 = Seconds       bin/bcd (0-59)
	-- 000001 = 01 = Seconds Alarm bin/bcd (0-59)
	-- 000010 = 02 = Minutes       bin/bcd (0-59)
	-- 000011 = 03 = Minutes Alarm bin/bcd (0-59)
	-- 000100 = 04 = Hours         bin/bcd (1-12 or 0-23)
   -- 000101 = 05 = Hours Alarm   bin/bcd (1-12 or 0-23)
   -- 000110 = 06 = Day of Week   bin/bcd (1-7, sunday = 1)
   -- 000111 = 07 = Date of Month bin/bcd (1-31)
   -- 001000 = 08 = Month         bin/bcd (1-12)
	-- 001001 = 09 = Year          bin/bcd (0-99)
	-- 001010 = 0A = Register A RW 7-UIP, 6-DV2, 5-DV1, 4-DV0, 3-RS3, 2-RS2, 1-RS1, 0-RS0. 
	--                             (UIP = update in progress, DV-dividers, RS-rate selection)
	-- 001011 = 0B = Register B RW 7-SET, 6-PIE, 5-AIE, 4-UIE, 3-SQWE, 2-DM, 1-24/12. 0-DSE 
	--                             (SET=update mode, PIE=int en, AIE=alarm int en, UIE=update int en, SQWE, DM 1=bcd, 0=bin, 24/12 1=24,0=12, DSE=daylight saving mode 1/0)
	-- 001100 = 0C = Register C RO 7-IRFQ, 6-PF, 5-AF, 4-UF, 0000
	-- 001101 = 0D = Register D RO 7-VRT, 0000000 (VRT = valid ram and time)
	-- 001110 = 0E = Register E - memory, 50 bytes
	-- ...
	-- 011111 = 3F = Register 3F
	
	-- memory for rtc registers
	URTC: entity work.dpram 
	generic map(
		DATAWIDTH => 8,
		ADDRWIDTH => 8
	)
	port map (
		clock	 => CLK,
		data_a	 => rtcw_di,
		address_a => rtcw_a,
		wren_a 	 => rtcw_wr,
		q_a => open,
		
		address_b => RTC_A,
		data_b => "00000000",
		wren_b => '0',
		q_b	 => rtcr_do
	);
	RTC_DO <= rtcr_do;
	
	-- fifo for write commands to send them on mcu side 
	UFIFO: entity work.fifo
	generic map (
		ADDR_WIDTH => 9,
		DATA_WIDTH => 24
	)
	port map (
		clk 	=> CLK,
		reset  => not N_RESET,

		empty  => queue_rd_empty,
		full   => queue_wr_full,
		
		rd     => queue_rd_req,
		dout  => queue_do,
		
		wr     => queue_wr_req,
		din 		=> queue_di
	);
	
	-- fifo handling / queue commands to mcu side
	process(CLK)
	begin
		if rising_edge(CLK) then
			queue_wr_req <= '0';
			IMG_Q_ACK <= '0';
			if caps_req /= caps_ack then -- answer the capability query
				queue_wr_req <= '1';
				queue_di <= CMD_CAPS & CAPS & CAPS_MAX_MHZ;
				caps_ack <= caps_req;
			elsif UART_TX_WR = '1' then -- send UART byte
				queue_wr_req <= '1';
				queue_di <= CMD_UART & "00000000" & UART_TX_DATA;
			elsif RTC_WR_N = '0' AND RTC_CS = '1' and BUSY = '0' and (RTC_A /= x"0C" and RTC_A /= x"0D") then -- add rtc register write to queue
			--elsif RTC_WR_N = '0' AND RTC_CS = '1' and BUSY = '0' and (RTC_A /= x"0C" and RTC_A < x"F0") then -- add rtc register write to queue
				queue_wr_req <= '1';
				queue_di <= CMD_RTC & RTC_A & RTC_DI;
         elsif MATRIX_CMD_WR = '1' then -- send matrix cmd
				queue_wr_req <= '1';
				queue_di <= MATRIX_CMD;
			elsif IMG_Q_WR = '1' and IMG_Q_ACK = '0' and queue_wr_full = '0' then -- file mounter frame
				-- not in the clock after an ack: the sender is just putting up its next frame
				queue_wr_req <= '1';
				queue_di <= IMG_Q_DI;
				IMG_Q_ACK <= '1';
			elsif queue_rd_empty = '1' then -- anti-empty queue
				queue_wr_req <= '1';
				queue_di <= CMD_NOPE & x"0000";
			end if;
						
		end if;
	end process;
	
	-- write RTC registers into ram from host / mcu
	process (CLK) 
	begin 
		if rising_edge(CLK) then
			rtcw_wr <= '0';
			if RTC_WR_N = '0' AND RTC_CS = '1' and BUSY = '0' then
				-- rtc mem write by host
				rtcw_wr <= '1';
				rtcw_a <= RTC_A;
				rtcw_di <= RTC_DI;
			elsif last_rtcr_command /= rtcr_command then
				-- rtc mem write by mcu
				rtcw_wr <= '1';
				rtcw_a <= rtcr_a;
				rtcw_di <= rtcr_d;
				last_rtcr_command <= rtcr_command;
			end if;
		end if;
	end process;

end RTL;

