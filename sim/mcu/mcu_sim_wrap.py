# ISim leaves vhdl 'buffer' ports undriven when a verilog module instantiates the entity.
# Writes mcu_sim.vhd: the mcu entity renamed to mcu_core, and a wrapper entity mcu with 'out'
# ports in place of the 'buffer' ones.
import re, sys
src = open(sys.argv[1]).read()
ent = re.search(r'entity mcu is(.*?)end mcu;', src, re.S | re.I).group(1)
core = re.sub(r'\bentity mcu is', 'entity mcu_core is', src, flags=re.I)
core = re.sub(r'\bend mcu;', 'end mcu_core;', core, flags=re.I)
core = re.sub(r'\barchitecture (\w+) of mcu is', r'architecture \1 of mcu_core is', core, flags=re.I)
ports = re.findall(r'^\s*(\w+)\s*:\s*(in|out|buffer)\s+([^;\n]*?)(?:\s*:=\s*[^;\n]*)?\s*;?\s*(?:--.*)?$',
                   ent.split('port', 1)[1], re.M | re.I)
bufs = [p for p in ports if p[1].lower() == 'buffer']
wrap = "library ieee;\nuse ieee.std_logic_1164.all;\n\nentity mcu is" + re.sub(r'\bbuffer\b', 'out', ent, flags=re.I) + "end mcu;\n\n"
wrap += "architecture sim of mcu is\n"
for n, d, t in bufs:
    wrap += "\tsignal %s_s : %s;\n" % (n, t.strip())
wrap += "begin\n\tU: entity work.mcu_core generic map (BURST_MAX_MHZ => BURST_MAX_MHZ) port map (\n"
wrap += ",\n".join("\t\t%s => %s%s" % (n, n, "_s" if d.lower() == 'buffer' else "") for n, d, t in ports)
wrap += "\n\t);\n"
for n, d, t in bufs:
    wrap += "\t%s <= %s_s;\n" % (n, n)
wrap += "end sim;\n"
open(sys.argv[2], "w").write(core + "\n\n" + wrap)
