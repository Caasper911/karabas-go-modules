#!/bin/bash
# pcm5102.v and kg_pcm5102.v (tb_pcm5102.v, the I2S stream) and audio_peaks.v (tb_audio_peaks.v), Icarus Verilog.
# Both print "0 errors".
set -e
cd "$(dirname "$0")"
M=$(cd ../.. && pwd)
mkdir -p ../build/audio
cd ../build/audio
# kg_pcm5102: the same testbench, strict
iverilog -g2001 -Wall -Wno-timescale -DKG_PCM5102 -o tb_kg_pcm5102.vvp "$M/sim/audio/tb_pcm5102.v" "$M/rtl/audio/kg_pcm5102.v"
vvp -n tb_kg_pcm5102.vvp > tb_kg_pcm5102.log
grep -E "ERROR|tb_pcm5102:" tb_kg_pcm5102.log | sed 's/^/kg_pcm5102: /'
grep -q "tb_pcm5102: 0 errors" tb_kg_pcm5102.log
for m in pcm5102 audio_peaks; do
	tb=tb_$m
	iverilog -g2001 -Wall -Wno-timescale -o $tb.vvp "$M/sim/audio/$tb.v" "$M/rtl/audio/$m.v"
	vvp -n $tb.vvp > $tb.log
	grep -E "ERROR|$tb:" $tb.log
	grep -q "$tb: 0 errors" $tb.log
done
