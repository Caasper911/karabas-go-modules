#!/bin/bash
# The MCU link with a model of the mcu firmware, ISim (ISE 14.7), about a minute:
# - tb_mem.v with dpram_sim.vhd / fifo_sim.vhd: the VHDL models below match dpram.v / fifo.v;
# - tb_mcu.v: mcu.vhd, spi_slave, burst_rx and the reply queue, every command;
# - tb_img.v: mcu.vhd + img_sdc.v, the file mounter (reads, bursts, lost frames, writes).
# Usage: sim/mcu/run_mcu_sim.sh [ns between mcu frames, default 500]
# Each prints "0 errors".
# ISim cannot elaborate dpram.v / fifo.v from VHDL with open ports (the VHDL models take their
# place), and leaves VHDL 'buffer' ports undriven towards Verilog (mcu_sim_wrap.py).
set -e
FRAME_GAP=${1:-500}
set --
source /opt/Xilinx/14.7/ISE_DS/settings64.sh > /dev/null
cd "$(dirname "$0")"
M=$(cd ../.. && pwd)
mkdir -p ../build/mcu
cd ../build/mcu
echo "run all; quit" > run.tcl

python3 -c 'print("\n".join("%03x" % ((i * 37 + 5) & 0xFFF) for i in range(512)))' > rom.hex
{
	echo "vhdl work \"$M/sim/mcu/fifo_sim.vhd\""
	echo "vhdl work \"$M/sim/mcu/dpram_sim.vhd\""
	for f in "$M"/rtl/mem/kg_*.v "$M/sim/mem/tb_mem.v"; do echo "verilog work \"$f\""; done
} > mem.prj
fuse -prj mem.prj -d VHDL_MODELS -top work.tb_mem -o tb_mem.exe > fuse_mem.log || { grep ERROR fuse_mem.log; exit 1; }
./tb_mem.exe -tclbatch run.tcl > tb_mem.log
grep -E "ERROR|tb_mem:" tb_mem.log
grep -q "tb_mem: 0 errors" tb_mem.log

python3 "$M/sim/mcu/mcu_sim_wrap.py" "$M/rtl/mcu/mcu.vhd" mcu_sim.vhd
for tb in tb_mcu tb_img; do
	{
		echo "vhdl work \"$M/sim/mcu/fifo_sim.vhd\""
		echo "vhdl work \"$M/sim/mcu/dpram_sim.vhd\""
		echo "vhdl work \"$M/rtl/mcu/spi_slave.vhd\""
		echo "vhdl work \"$M/rtl/mcu/burst_rx.vhd\""
		echo "vhdl work \"mcu_sim.vhd\""
		echo "verilog work \"$M/rtl/mcu/img_sdc.v\""
		echo "verilog work \"$M/sim/mcu/$tb.v\""
	} > $tb.prj
	fuse -prj $tb.prj -top work.$tb -generic_top "FRAME_GAP=$FRAME_GAP" -o $tb.exe > fuse_$tb.log || { grep ERROR fuse_$tb.log; exit 1; }
	./$tb.exe -tclbatch run.tcl > $tb.log
	grep -E "ERROR|$tb:" $tb.log
	grep -q "$tb: 0 errors" $tb.log
done
