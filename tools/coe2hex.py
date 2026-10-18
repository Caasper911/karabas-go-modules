#!/usr/bin/env python3
"""Convert a Xilinx coregen .coe file to a $readmemh .hex file (one word per line).

Usage: coe2hex.py in.coe out.hex [width]

The radix of the .coe (memory_initialization_radix 2, 10 or 16) is converted to hex. The width
(bits) sets the number of hex digits per line; without it the widest value decides.
"""
import re
import sys


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    text = open(sys.argv[1]).read()
    # a line that starts with ';' is a comment, other ';' end a statement
    stmts = [s.strip() for s in re.sub(r"(?m)^\s*;.*$", "", text).split(";") if s.strip()]
    radix = 10
    values = []
    for s in stmts:
        k, _, v = s.partition("=")
        k = k.strip().lower()
        if k == "memory_initialization_radix":
            radix = int(v.strip())
        elif k == "memory_initialization_vector":
            values = [int(x, radix) for x in re.split(r"[\s,]+", v.strip()) if x]
    if not values:
        sys.exit("no memory_initialization_vector in " + sys.argv[1])
    bits = int(sys.argv[3]) if len(sys.argv) == 4 else max(1, max(values).bit_length())
    digits = (bits + 3) // 4
    with open(sys.argv[2], "w") as f:
        for x in values:
            f.write("%0*x\n" % (digits, x))


if __name__ == "__main__":
    main()
