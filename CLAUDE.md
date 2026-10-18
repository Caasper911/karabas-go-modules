# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Shared FPGA modules for the Karabas Go / Mini / Mini G cores (`karabas-go-core-*`): Xilinx Spartan-6 XC6SLX25, ISE 14.7 (XST). The cores used to carry their own copies of these modules, which diverged (16 versions of `mcu.vhd` in 17 cores). This repository holds the one maintained version; the cores include it as a git submodule.

Status: stage 0 of `docs/PLAN.md` (Russian; the analysis of the existing copies and the migration plan). Follow its stages; update the plan when a decision changes. The files in `rtl/` are still the nanomig versions, byte for byte, with their original module names; the `kg_` prefix comes with the rewrite of each module. karabas-go-core-nanomig is the first core that uses this repository (submodule `modules/`).

How a core uses it: the submodule is at `<core>/modules` (relative URL `../karabas-go-modules.git`, so it follows the ssh or https remote of the core), and the core's XST `.prj` lists the files it needs with paths relative to its build directory (`"../modules/rtl/..."` from `src/`). Simulation scripts of the core that rewrite prj paths must handle `../modules/` as well.

The reference versions are those of `karabas-go-core-nanomig` (sibling directory `../karabas-go-core-nanomig`): its MCU link has the reliability fixes (chip select deglitch, `spi_ssel` gated during bursts, reply words popped on `do_valid`, no `di_req` in idle in `spi_slave`) that no other core has yet. Its `CLAUDE.md` documents why each of them was needed.

## Related repositories (siblings in `..`)

- `karabas-go-core-*`: the cores that use these modules.
- `karabas-go-firmware`: the MCU side of the link. `src/config.h` has the command codes, `docs/protocol.md` and `docs/burst_protocol.md` the protocol. A change of the link here has to match it.
- `karabas-go-tools`: `make_core.py` (packs the bitstream and ROMs into `.kg1/.kg2/.kg3`).

## Layout (see docs/PLAN.md section 3)

Now: `rtl/mcu` (`mcu.vhd`, `spi_slave.vhd`, `burst_rx.vhd`, `img_sdc.v`), `rtl/mem` (`dpram.v`, `fifo.v`, and the coregen replacements `kg_spram`, `kg_sprom`, `kg_sdpram`, `kg_tdpram`, `kg_dist_sdpram`, `kg_dist_spram`), `rtl/clk` (`kg_pll`, `kg_dcm`), `rtl/audio` (`pcm5102.v`, `dac.vhd`, `audio_peaks.v`), `rtl/video/hdmi` (`zhdmi_top.v`, zhdmi, `hdmi_pll.v`, `dvi*.vhd`), `rtl/video/osd` (`overlay.vhd`, `pix_doubler.vhd`).

Planned:

- `rtl/mcu`: the MCU link (`kg_mcu_link`), the per-feature command decoders and the compatibility wrapper `kg_mcu`.
- `rtl/hid`, `rtl/ctl`, `rtl/mem`, `rtl/clk`, `rtl/audio`, `rtl/video/{hdmi,osd}`: the other shared modules.
- `boards/{go,mini,minig}`: pin constraints (`pins.ucf`, LOC/IOSTANDARD only) per board.
- `prj/kg_modules.prj`: the source list a core's build script appends to its own prj.
- `sim/`: testbenches, models (MCU firmware, SDRAM, SRAM) and run scripts.
- `tools/`: `coe2hex.py` and other helpers.

## Conventions

- **Module names start with `kg_`**, so they do not collide with the cores' own modules (`zxnext/*` of the next core has its own `dpram`, `dac`, `spi_master`), coregen cores or upstream code.
- **Verilog-2001 that XST accepts.** No declarations in unnamed blocks (name the block), no `'1` literals, no `` `default_nettype none `` headers, no SystemVerilog. New modules are Verilog; third-party VHDL (zhdmi, TMDS encoder) stays VHDL until it has tests.
- **No coregen (ipcore).** Memories and FIFOs are inferred RTL; clocks instantiate `PLL_BASE` / `DCM_SP` directly (`kg_pll`, `kg_dcm`). ROM contents come from `.hex` files through `$readmemh` (`tools/coe2hex.py` converts `.coe`).
- **Optional features are parameters (`ENABLE_*`) with `generate`**, so a core that does not use a feature does not build it. Several cores fill 96-99% of the slices: check LUT counts when a module changes.
- **Interfaces are stable.** A port change is a major version (tag `vX.Y`, `CHANGELOG`); keep a compatibility wrapper for at least one major version. Cores pin the submodule commit, so a change here reaches a core only when it updates its submodule.
- Imported code keeps its upstream form; local changes are marked with a `// karabas:` comment that says why.
- Commit messages explain why a change was needed and what it costs or changes in behaviour (latency, LUT counts before and after), and say "No functional change." when that is the case.

## Verifying a change

- `sim/ipcore_eq/run_ipcore_eq.sh` (ISim, ~20 s): the `kg_*` memories and clocks against the coregen cores they replace, from the `ipcore_dir` of the sibling cores (models from `$XILINX/verilog/src/XilinxCoreLib`, which ISE has as source only). Memories: random stimulus, every output every clock; clocks: every edge. Both must print `0 errors`. When a core replaces another coregen core, add the pair there first.
- The coregen models zero their memories and outputs; the `kg_*` memories do the same in simulation (a loop hidden from XST by `translate_off`, as XST limits loop iterations) and XST starts the block RAMs at 0, so both match on the FPGA.
- Check what XST infers ("Advanced HDL Synthesis Report" of the `.syr`: block or distributed RAM, size, write-first / read-first) and the RAMB16 / RAMB8 count against the coregen build.

- Simulate the module (ISim for mixed VHDL/Verilog; iverilog / verilator lint for pure Verilog). A rewrite of an existing module is checked against the old one with the same stimulus, output by output, clock by clock.
- Build at least one core that uses the module and compare utilization (`*_map.mrp`) and timing (`*.par`, "All constraints were met") with the build before the change.
- Changes to the MCU link need a check on hardware with the firmware: rom loading, OSD, keyboard, joysticks, file mounter.
