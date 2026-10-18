#!/usr/bin/env python3
"""Init files and Verilog wrappers for run_ipcore_eq.sh (run in the build directory).

Usage: gen_models.py <karabas-go directory with the sibling cores>

- font.mif / font.hex: the rk86 font ROM (.mif for the coregen model, .hex for kg_sprom);
- keyjoy_sdpram_64_6.mif / keyjoy.hex: the next keyjoy distributed RAM;
- <core>_ver.v: Verilog wrappers of the next dist_mem_gen cores (ISE has the VHDL model only as
  a Verilog DIST_MEM_GEN_V7_2), with the generics of their .vhd.
"""
import re
import sys

K = sys.argv[1]
NEXT = K + "/karabas-go-core-next/src/ipcore_dir/"

coe = open(K + "/karabas-go-core-rk86/src/roms/FONT.coe").read()
vec = coe.split("=", 2)[2]
vals = [int(x, 16) for x in re.split(r"[\s,;]+", vec) if x]
open("font.mif", "w").write("".join("{:08b}\n".format(x) for x in vals))
open("font.hex", "w").write("".join("%02x\n" % x for x in vals))

mif = [l.strip() for l in open(NEXT + "keyjoy_sdpram_64_6.mif") if l.strip()]
open("keyjoy_sdpram_64_6.mif", "w").write("\n".join(mif) + "\n")
open("keyjoy.hex", "w").write("".join("%02x\n" % int(x, 2) for x in mif))

for name, ports in [("keyjoy_sdpram_64_6", "a,d,dpra,clk,we,dpo"), ("spram_320_9", "a,d,clk,we,spo")]:
    v = open(NEXT + name + ".vhd").read()
    gen = {}
    for k, val in re.findall(r"(c_[a-z_]+)\s*=>\s*([^,\)\n]+)", v):
        gen.setdefault(k, val.strip())
    aw, dw = gen["c_addr_width"], gen["c_width"]
    decl = {"a": "input [%s-1:0] a;" % aw, "dpra": "input [%s-1:0] dpra;" % aw, "d": "input [%s-1:0] d;" % dw,
            "clk": "input clk;", "we": "input we;", "dpo": "output [%s-1:0] dpo;" % dw,
            "spo": "output [%s-1:0] spo;" % dw}
    ps = ports.split(",")
    out = ["module %s(%s);" % (name, ports)] + [decl[p] for p in ps]
    out.append("DIST_MEM_GEN_V7_2 #(\n  %s\n) inst (%s);" % (
        ",\n  ".join(".%s(%s)" % (k.upper(), val) for k, val in gen.items()),
        ", ".join(".%s(%s)" % (p.upper(), p) for p in ps)))
    out.append("endmodule")
    open(name + "_ver.v", "w").write("\n".join(out) + "\n")
