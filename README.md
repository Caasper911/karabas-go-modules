# karabas-go-modules

Shared FPGA modules for the [Karabas Go](https://github.com/andykarpov/karabas-go) / Mini / Mini G cores (Spartan-6 XC6SLX25, ISE 14.7).

The cores include this repository as a git submodule in `modules/` and list the files they use in their XST `.prj` (paths relative to the build directory, for example `"../modules/rtl/mcu/mcu.vhd"`).

| Directory | Contents |
|---|---|
| `rtl/mcu` | MCU link: `mcu.vhd` (SPI commands of [karabas-go-firmware](https://github.com/andykarpov/karabas-go-firmware) `docs/protocol.md`), `spi_slave.vhd`, `burst_rx.vhd` (`docs/burst_protocol.md`), `img_sdc.v` (file mounter as a sector interface) |
| `rtl/mem` | `dpram.v`, `fifo.v`; inferred replacements of the coregen memories: `kg_spram`, `kg_sprom`, `kg_sdpram`, `kg_tdpram` (byte write enables), `kg_dist_sdpram`, `kg_dist_spram` |
| `rtl/clk` | `kg_pll` (PLL_BASE), `kg_dcm` (DCM_SP): the coregen clocking wizard cores with the same parameters |
| `rtl/audio` | `pcm5102.v` (I2S DAC), `dac.vhd` (sigma-delta), `audio_peaks.v` (level meters of the MCU) |
| `rtl/video/hdmi` | `zhdmi_top.v` and the zhdmi HDMI transmitter, `hdmi_pll.v`, `dvi*.vhd` |
| `rtl/video/osd` | `overlay.vhd` (OSD menus of the MCU), `pix_doubler.vhd` |

`tools/coe2hex.py` converts a coregen `.coe` into the `$readmemh` file of the `INIT_FILE` parameters. `sim/ipcore_eq/run_ipcore_eq.sh` simulates the `kg_*` memories and clocks against the coregen cores they replace (needs the sibling core repositories).

The modules came from [karabas-go-core-nanomig](https://github.com/andykarpov/karabas-go-core-nanomig), whose MCU link has the latest fixes. The plan for the other cores and the next steps (Verilog rewrite, split of `mcu`, removal of the coregen cores) is in [docs/PLAN.md](docs/PLAN.md).
