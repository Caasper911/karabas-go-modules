# karabas-go-modules

Shared FPGA modules for the [Karabas Go](https://github.com/andykarpov/karabas-go) / Mini / Mini G cores (Spartan-6 XC6SLX25, ISE 14.7).

The cores include this repository as a git submodule in `modules/` and list the files they use in their XST `.prj` (paths relative to the build directory, for example `"../modules/rtl/mcu/mcu.vhd"`).

| Directory | Contents |
|---|---|
| `rtl/mcu` | MCU link: `mcu.vhd` (SPI commands of [karabas-go-firmware](https://github.com/andykarpov/karabas-go-firmware) `docs/protocol.md`), `spi_slave.vhd`, `burst_rx.vhd` (`docs/burst_protocol.md`), `img_sdc.v` (file mounter as a sector interface) |
| `rtl/mem` | `dpram.v`, `fifo.v` |
| `rtl/audio` | `pcm5102.v` (I2S DAC), `dac.vhd` (sigma-delta), `audio_peaks.v` (level meters of the MCU) |
| `rtl/video/hdmi` | `zhdmi_top.v` and the zhdmi HDMI transmitter, `hdmi_pll.v`, `dvi*.vhd` |
| `rtl/video/osd` | `overlay.vhd` (OSD menus of the MCU), `pix_doubler.vhd` |

The modules came from [karabas-go-core-nanomig](https://github.com/andykarpov/karabas-go-core-nanomig), whose MCU link has the latest fixes. The plan for the other cores and the next steps (Verilog rewrite, split of `mcu`, removal of the coregen cores) is in [docs/PLAN.md](docs/PLAN.md).
