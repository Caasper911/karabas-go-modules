-- unisim.vcomponents for the ghdl analysis of run_lint.sh: the component declarations of the
-- Xilinx primitives the VHDL files instantiate (interface of the ISE 14.7 unisims).
library ieee;
use ieee.std_logic_1164.all;

package vcomponents is
	component ODDR2
		generic (
			DDR_ALIGNMENT : string := "NONE";
			INIT : bit := '0';
			SRTYPE : string := "SYNC"
		);
		port (
			Q : out std_ulogic;
			C0 : in std_ulogic;
			C1 : in std_ulogic;
			CE : in std_ulogic := 'H';
			D0 : in std_ulogic;
			D1 : in std_ulogic;
			R : in std_ulogic := 'L';
			S : in std_ulogic := 'L'
		);
	end component;

	component OBUFDS
		generic (
			CAPACITANCE : string := "DONT_CARE";
			IOSTANDARD : string := "DEFAULT";
			SLEW : string := "SLOW"
		);
		port (
			O : out std_ulogic;
			OB : out std_ulogic;
			I : in std_ulogic
		);
	end component;
end vcomponents;
