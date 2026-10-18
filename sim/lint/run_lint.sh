#!/bin/bash
# Lint of rtl/ (seconds):
# - kg_*.v: verilator --lint-only -Wall, no warning allowed (the new modules);
# - the other Verilog files: verilator --lint-only, errors fail, warnings are shown (imported code,
#   fixed when a module is rewritten);
# - VHDL: ghdl analysis (-fexplicit --ieee=synopsys for std_logic_arith / _unsigned).
# Xilinx primitives and the VHDL entities used from Verilog are black boxes (xilinx_stubs.v).
set -e
cd "$(dirname "$0")/../.."
STUBS=sim/lint/xilinx_stubs.v
# the kg_* modules a module instantiates are found in these directories
YDIRS=$(find rtl -type d | sed 's/^/-y /')
fail=0

top_of() { grep -m1 -oP '^\s*module\s+\K\w+' "$1"; }

for f in $(find rtl -name 'kg_*.v' | sort); do
	if ! out=$(verilator --lint-only -Wall -Wno-PINCONNECTEMPTY --top-module "$(top_of "$f")" $YDIRS "$f" $STUBS 2>&1); then
		echo "$out" | grep -v '^%Error: Exiting'
		fail=1
	fi
done
echo "verilator -Wall: kg_*.v done"

for f in $(find rtl -name '*.v' ! -name 'kg_*' | sort); do
	out=$(verilator --lint-only -Wno-fatal -Wno-PINCONNECTEMPTY -Wno-TIMESCALEMOD --top-module "$(top_of "$f")" \
		-y rtl/video/hdmi "$f" $STUBS 2>&1) || fail=1
	echo "$out" | grep '^%' | grep -v '^%Error: Exiting' | sed 's/^%/  %/' || true
done
echo "verilator: imported Verilog done"

if command -v ghdl > /dev/null; then
	W=sim/build/lint
	rm -rf $W
	mkdir -p $W
	# spi_slave.vhd: case choices from generics, which ISE takes (HDLCompiler:957) and ghdl does
	# not in any standard; its entity only, so that mcu.vhd is checked (kg_spi_slave, stage 2)
	{ echo "library ieee; use ieee.std_logic_1164.all;"; sed -n '/^entity spi_slave/,/^end spi_slave;/p' rtl/mcu/spi_slave.vhd
	  echo "architecture stub of spi_slave is begin end stub;"; } > $W/spi_slave_entity.vhd
	# mcu.vhd and overlay.vhd instantiate dpram.v and fifo.v: their VHDL models
	python3 sim/lint/ghdl_check.py $W sim/mcu/dpram_sim.vhd sim/mcu/fifo_sim.vhd $W/spi_slave_entity.vhd \
		$(find rtl -name '*.vhd' ! -name spi_slave.vhd | sort) || fail=1
else
	echo "ghdl not installed: VHDL not checked"
fi

[ $fail = 0 ] && echo "lint: ok" || { echo "lint: FAILED"; exit 1; }
