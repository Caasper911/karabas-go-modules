#!/bin/bash
# The kg_* Verilog ports against the modules they replace, same random stimulus, every output
# compared. Each prints "0 errors".
# - iverilog, with the VHDL turned into a Verilog netlist by ghdl --synth (also in the CI):
#   dac / kg_sigma_delta_dac, pix_doubler / kg_pix_doubler, burst_rx / kg_burst_rx, and from
#   other cores (copies in sim/eq/ref) soft_switches / kg_soft_switches, cursor / kg_cursor;
# - ISim (ISE 14.7), mixed VHDL / Verilog: spi_slave / kg_spi_slave (ghdl rejects spi_slave.vhd),
#   overlay / kg_osd_overlay (its latches, a minute), mcu.vhd of nanomig / kg_mcu (a minute).
# Usage: sim/eq/run_eq.sh [--no-isim]; EQ_ONLY=tb_eq_mcu runs that one only.
set -e
cd "$(dirname "$0")"
M=$(cd ../.. && pwd)
mkdir -p ../build/eq
cd ../build/eq

want() { [ -z "$EQ_ONLY" ] || [ "$EQ_ONLY" = "$1" ]; }

result() { # testbench: its result lines, fails unless 0 errors
	grep -E "ERROR|$1:" $1.log
	grep -q "$1: 0 errors" $1.log
}

run_iv() { # testbench, vhdl file, entity, new module file
	want $1 || return 0
	ghdl --synth --std=08 -fexplicit --ieee=synopsys --out=verilog "$M/$2" -e $3 > $3_vhdl.v
	iverilog -g2001 -Wall -Wno-timescale -Wno-implicit-dimensions -I "$M/sim/eq" -o $1.vvp \
		"$M/sim/eq/$1.v" $3_vhdl.v "$M/$4"
	vvp -n $1.vvp > $1.log
	result $1
}

run_iv tb_eq_dac rtl/audio/dac.vhd dac rtl/audio/kg_sigma_delta_dac.v
run_iv tb_eq_pix_doubler rtl/video/osd/pix_doubler.vhd pix_doubler rtl/video/osd/kg_pix_doubler.v
run_iv tb_eq_burst_rx rtl/mcu/burst_rx.vhd burst_rx rtl/mcu/kg_burst_rx.v
run_iv tb_eq_soft_switches sim/eq/ref/tsconf_soft_switches.vhd soft_switches rtl/ctl/kg_soft_switches.v

# cursor: the four variants, each netlist with its own module name
if want tb_eq_cursor; then
	for c in tsconf profi next test; do
		# (ghdl warns about the unused top bits of the deltas)
		ghdl --synth --std=08 -fexplicit --ieee=synopsys --out=verilog "$M/sim/eq/ref/${c}_cursor.vhd" -e cursor 2> /dev/null |
			sed "s/^module cursor\b/module cursor_$c/" > cursor_$c.v
	done
	iverilog -g2001 -Wall -Wno-timescale -Wno-implicit-dimensions -I "$M/sim/eq" -o tb_eq_cursor.vvp \
		"$M/sim/eq/tb_eq_cursor.v" cursor_*.v "$M/rtl/hid/kg_cursor.v"
	vvp -n tb_eq_cursor.vvp > tb_eq_cursor.log
	result tb_eq_cursor
fi

[ "$1" = "--no-isim" ] && exit 0
if [ ! -f /opt/Xilinx/14.7/ISE_DS/settings64.sh ]; then echo "no ISE: spi_slave, overlay, mcu not compared"; exit 0; fi
source /opt/Xilinx/14.7/ISE_DS/settings64.sh > /dev/null
echo "run all; quit" > run.tcl

run_isim() { # testbench, tcl file; the prj is in <testbench>.prj
	fuse -prj $1.prj -top work.$1 -o $1.exe > fuse_$1.log || { grep ERROR fuse_$1.log; exit 1; }
	./$1.exe -tclbatch $2 > $1.log
	result $1
}

if want tb_eq_overlay; then
	cat > tb_eq_overlay.prj <<PRJ
vhdl work "$M/sim/mcu/dpram_sim.vhd"
vhdl work "$M/rtl/video/osd/pix_doubler.vhd"
vhdl work "$M/rtl/video/osd/overlay.vhd"
verilog work "$M/rtl/mem/kg_sdpram.v"
verilog work "$M/rtl/video/osd/kg_pix_doubler.v"
verilog work "$M/rtl/video/osd/kg_osd_overlay.v"
verilog work "$M/sim/eq/tb_eq_overlay.v" -i "$M/sim/eq"
PRJ
	# the flash counter of overlay.vhd has no initial value: held as in the testbench
	printf 'isim force add /tb_eq_overlay/old_dut/flash_cnt 00000000 -radix bin -value 00100000 -radix bin -time 60ms\nrun all\nquit\n' > force.tcl
	run_isim tb_eq_overlay force.tcl
fi

if want tb_eq_mcu; then
	python3 "$M/sim/mcu/mcu_sim_wrap.py" "$M/rtl/mcu/mcu.vhd" mcu_sim.vhd
	{
		echo "vhdl work \"$M/sim/mcu/fifo_sim.vhd\""
		echo "vhdl work \"$M/sim/mcu/dpram_sim.vhd\""
		echo "vhdl work \"$M/rtl/mcu/spi_slave.vhd\""
		echo "vhdl work \"$M/rtl/mcu/burst_rx.vhd\""
		echo "vhdl work \"mcu_sim.vhd\""
		for f in rtl/mem/kg_fifo.v rtl/mem/kg_sdpram.v rtl/mcu/kg_spi_slave.v rtl/mcu/kg_burst_rx.v \
			$(cd "$M" && ls rtl/mcu/kg_mcu*.v) sim/eq/tb_eq_mcu.v; do
			echo "verilog work \"$M/$f\" -i \"$M/rtl/mcu\" -i \"$M/sim/eq\""
		done
	} > tb_eq_mcu.prj
	run_isim tb_eq_mcu run.tcl
fi

if want tb_eq_spi_slave; then
	cat > tb_eq_spi_slave.prj <<PRJ
vhdl work "$M/rtl/mcu/spi_slave.vhd"
verilog work "$M/rtl/mcu/kg_spi_slave.v"
verilog work "$M/sim/eq/tb_eq_spi_slave.v" -i "$M/sim/eq"
PRJ
	run_isim tb_eq_spi_slave run.tcl
fi
