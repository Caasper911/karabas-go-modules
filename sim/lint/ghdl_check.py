#!/usr/bin/env python3
"""ghdl analysis of the VHDL files (run_lint.sh). Usage: ghdl_check.py workdir file...

ISE takes VHDL that ghdl splits between the standards: port maps with expressions need 2008,
an aggregate of zhdmi_packet_gen.vhd is ambiguous in 2008 and fine in 93. So every file is
analysed in 93, then in 2008; a file passes in either. A file that passed only in 93 gives the
2008 library a stub of its entities, so that the files using them are checked in 2008.
ghdl wants an entity analysed before its users: a file that fails is tried again after the
others, until nothing changes. Exits 1 and shows the errors of the files that pass in neither.
"""
import os
import re
import subprocess
import sys

FLAGS = ["-frelaxed", "-fexplicit", "--ieee=synopsys"]


def analyse(std, work, f):
    r = subprocess.run(["ghdl", "-a", "--std=" + std, "--workdir=" + work, "-P" + work] + FLAGS + [f],
                       capture_output=True, text=True)
    return r.returncode == 0, r.stderr


def run_pass(std, work, files, stubs=None):
    """analyses files in dependency order; stubs: file -> stub file to use once it is stuck"""
    os.makedirs(work, exist_ok=True)
    ok, todo, errs = set(), list(files), {}
    while todo:
        left = []
        for f in todo:
            good, err = analyse(std, work, f)
            if good:
                ok.add(f)
            else:
                left.append(f)
                errs[f] = err
        if len(left) == len(todo):
            stub = [f for f in left if stubs and f in stubs]
            if not stub:
                break
            for f in stub:
                analyse(std, work, stubs[f])
                left.remove(f)
        todo = left
    return ok, errs


def entity_stub(src, dst):
    text = open(src).read()
    blocks = re.finditer(r"^\s*entity\s+(\w+)\s+is\b.*?^\s*end(?:\s+entity)?(?:\s+\1)?\s*;", text, re.M | re.S | re.I)
    with open(dst, "w") as out:
        for m in blocks:
            out.write("library ieee;\nuse ieee.std_logic_1164.all;\nuse ieee.numeric_std.all;\n")
            out.write(m.group(0) + "\n")
            out.write("architecture stub of %s is\nbegin\nend stub;\n\n" % m.group(1))


def main():
    work, files = sys.argv[1], sys.argv[2:]
    # unisim: the component declarations of the Xilinx primitives
    here = os.path.dirname(os.path.abspath(__file__))
    for std, d in (("93c", "93"), ("08", "08")):
        os.makedirs(os.path.join(work, d), exist_ok=True)
        subprocess.run(["ghdl", "-a", "--std=" + std, "--work=unisim", "--workdir=" + os.path.join(work, d),
                        os.path.join(here, "unisim_stubs.vhd")], check=True)
    ok93, errs93 = run_pass("93c", os.path.join(work, "93"), files)
    stubs = {}
    for f in ok93:
        dst = os.path.join(work, "stub_" + os.path.basename(f))
        entity_stub(f, dst)
        stubs[f] = dst
    ok08, errs08 = run_pass("08", os.path.join(work, "08"), files, stubs)
    bad = [f for f in files if f not in ok93 and f not in ok08]
    for f in bad:
        print("== %s\n-- VHDL-2008:\n%s-- VHDL-93:\n%s" % (f, errs08.get(f, ""), errs93.get(f, "")))
    print("ghdl: %d files, %d in VHDL-2008, %d only in VHDL-93, %d failed"
          % (len(files), len(ok08 - set(stubs.values())), len(ok93 - ok08), len(bad)))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
