#!/bin/bash
# The memories of rtl/mem (kg_*, dpram, fifo) against the model in tb_mem.v, Icarus Verilog
# (a second or two), and kg_async_fifo with tb_async_fifo.v (half a minute). Prints "tb_mem: 0 errors" and
# "tb_async_fifo: 0 errors".
set -e
cd "$(dirname "$0")"
M=$(cd ../.. && pwd)
mkdir -p ../build/mem
cd ../build/mem
python3 -c 'print("\n".join("%03x" % ((i * 37 + 5) & 0xFFF) for i in range(512)))' > rom.hex
iverilog -g2001 -Wall -Wno-timescale -o tb_mem.vvp "$M/sim/mem/tb_mem.v" \
	"$M"/rtl/mem/kg_*.v "$M/rtl/mem/dpram.v" "$M/rtl/mem/fifo.v"
vvp -n tb_mem.vvp > sim.log
grep -E "ERROR|checks|errors" sim.log
grep -q "tb_mem: 0 errors" sim.log
iverilog -g2001 -Wall -Wno-timescale -o tb_async_fifo.vvp "$M/sim/mem/tb_async_fifo.v" "$M/rtl/mem/kg_async_fifo.v"
vvp -n tb_async_fifo.vvp > async.log
grep -E "ERROR|words|errors" async.log
grep -q "tb_async_fifo: 0 errors" async.log
