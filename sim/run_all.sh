#!/bin/bash
# All tests of this repository.
# - always (the CI runs these): lint, memories, audio (verilator, Icarus Verilog, ghdl);
# - with ISE 14.7 in /opt/Xilinx/14.7: the MCU link (ISim), and the coregen equivalence when the
#   sibling core repositories are there.
cd "$(dirname "$0")"
fail=0
run() {
	echo "==== $1"
	"./$1" || { echo "==== $1 FAILED"; fail=1; }
}
run lint/run_lint.sh
run mem/run_mem_sim.sh
run audio/run_audio_sim.sh
if [ -f /opt/Xilinx/14.7/ISE_DS/settings64.sh ]; then
	run mcu/run_mcu_sim.sh
	if [ -d ../../karabas-go-core-next186 ]; then run ipcore_eq/run_ipcore_eq.sh; else echo "==== ipcore_eq: no sibling cores, skipped"; fi
else
	echo "==== no ISE: mcu, ipcore_eq skipped"
fi
[ $fail = 0 ] && echo "==== all passed" || { echo "==== FAILED"; exit 1; }
