#!/bin/bash
# The kg_* Verilog ports against the VHDL modules they replace, same random stimulus, every
# output compared (seconds). Each prints "0 errors".
# - iverilog, with the VHDL turned into a Verilog netlist by ghdl --synth (also in the CI):
#   dac / kg_sigma_delta_dac, pix_doubler / kg_pix_doubler, burst_rx / kg_burst_rx, and from
#   other cores (copies in sim/eq/ref) soft_switches / kg_soft_switches, cursor / kg_cursor;
# - ISim (ISE 14.7), mixed VHDL / Verilog: spi_slave / kg_spi_slave (ghdl rejects spi_slave.vhd),
#   overlay / kg_osd_overlay (its latches, a minute).
# Usage: sim/eq/run_eq.sh [--no-isim]
set -e
cd "$(dirname "$0")"
M=$(cd ../.. && pwd)
mkdir -p ../build/eq
cd ../build/eq

run_iv() { # testbench, vhdl file, entity, new module file
	ghdl --synth --std=08 -fexplicit --ieee=synopsys --out=verilog "$M/$2" -e $3 > $3_vhdl.v
	iverilog -g2001 -Wall -Wno-timescale -Wno-implicit-dimensions -I "$M/sim/eq" -o $1.vvp \
		"$M/sim/eq/$1.v" $3_vhdl.v "$M/$4"
	vvp -n $1.vvp > $1.log
	grep -E "ERROR|$1:" $1.log
	grep -q "$1: 0 errors" $1.log
}
run_iv tb_eq_dac rtl/audio/dac.vhd dac rtl/audio/kg_sigma_delta_dac.v
run_iv tb_eq_pix_doubler rtl/video/osd/pix_doubler.vhd pix_doubler rtl/video/osd/kg_pix_doubler.v
run_iv tb_eq_burst_rx rtl/mcu/burst_rx.vhd burst_rx rtl/mcu/kg_burst_rx.v
run_iv tb_eq_soft_switches sim/eq/ref/tsconf_soft_switches.vhd soft_switches rtl/ctl/kg_soft_switches.v

# cursor: the four variants, each netlist with its own module name
for c in tsconf profi next test; do
	# (ghdl warns about the unused top bits of the deltas)
	ghdl --synth --std=08 -fexplicit --ieee=synopsys --out=verilog "$M/sim/eq/ref/${c}_cursor.vhd" -e cursor 2> /dev/null |
		sed "s/^module cursor\b/module cursor_$c/" > cursor_$c.v
done
iverilog -g2001 -Wall -Wno-timescale -Wno-implicit-dimensions -I "$M/sim/eq" -o tb_eq_cursor.vvp \
	"$M/sim/eq/tb_eq_cursor.v" cursor_*.v "$M/rtl/hid/kg_cursor.v"
vvp -n tb_eq_cursor.vvp > tb_eq_cursor.log
grep -E "ERROR|tb_eq_cursor:" tb_eq_cursor.log
grep -q "tb_eq_cursor: 0 errors" tb_eq_cursor.log

[ "$1" = "--no-isim" ] && exit 0
if [ ! -f /opt/Xilinx/14.7/ISE_DS/settings64.sh ]; then echo "no ISE: spi_slave not compared"; exit 0; fi
(
	source /opt/Xilinx/14.7/ISE_DS/settings64.sh > /dev/null
	echo "run all; quit" > run.tcl
	tb=tb_eq_overlay
	cat > $tb.prj <<PRJ
vhdl work "$M/sim/mcu/dpram_sim.vhd"
vhdl work "$M/rtl/video/osd/pix_doubler.vhd"
vhdl work "$M/rtl/video/osd/overlay.vhd"
verilog work "$M/rtl/mem/kg_sdpram.v"
verilog work "$M/rtl/video/osd/kg_pix_doubler.v"
verilog work "$M/rtl/video/osd/kg_osd_overlay.v"
verilog work "$M/sim/eq/$tb.v" -i "$M/sim/eq"
PRJ
	fuse -prj $tb.prj -top work.$tb -o $tb.exe > fuse_$tb.log || { grep ERROR fuse_$tb.log; exit 1; }
	# the flash counter of overlay.vhd has no initial value: held as in the testbench
	printf 'isim force add /tb_eq_overlay/old_dut/flash_cnt 00000000 -radix bin -value 00100000 -radix bin -time 60ms\nrun all\nquit\n' > force.tcl
	./$tb.exe -tclbatch force.tcl > $tb.log
	grep -E "ERROR|$tb:" $tb.log
	grep -q "$tb: 0 errors" $tb.log

	tb=tb_eq_spi_slave
	cat > $tb.prj <<PRJ
vhdl work "$M/rtl/mcu/spi_slave.vhd"
verilog work "$M/rtl/mcu/kg_spi_slave.v" 
verilog work "$M/sim/eq/$tb.v" -i "$M/sim/eq"
PRJ
	fuse -prj $tb.prj -top work.$tb -o $tb.exe > fuse_$tb.log || { grep ERROR fuse_$tb.log; exit 1; }
	./$tb.exe -tclbatch run.tcl > $tb.log
	grep -E "ERROR|$tb:" $tb.log
	grep -q "$tb: 0 errors" $tb.log
)
