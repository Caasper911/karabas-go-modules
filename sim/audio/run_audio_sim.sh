#!/bin/bash
# pcm5102.v (tb_pcm5102.v, the I2S stream) and audio_peaks.v (tb_audio_peaks.v), Icarus Verilog.
# Both print "0 errors".
set -e
cd "$(dirname "$0")"
M=$(cd ../.. && pwd)
mkdir -p ../build/audio
cd ../build/audio
for m in pcm5102 audio_peaks; do
	tb=tb_$m
	iverilog -g2001 -Wall -Wno-timescale -o $tb.vvp "$M/sim/audio/$tb.v" "$M/rtl/audio/$m.v"
	vvp -n $tb.vvp > $tb.log
	grep -E "ERROR|$tb:" $tb.log
	grep -q "$tb: 0 errors" $tb.log
done
