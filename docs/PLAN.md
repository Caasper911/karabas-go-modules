# План объединения общих модулей karabas-go-core-*

Состояние на 2026-10-18. Эталон — `karabas-go-core-nanomig` (master 90dc1bc, 2026-10-17).

Цель: вынести общие модули ядер Karabas Go / Mini / Mini G в этот репозиторий, подключать их во все ядра и сопровождать из одного места. Попутно перевести свои модули на Verilog-2001 и отказаться от Xilinx coregen (ipcore).

## 1. Инвентаризация

Проанализировано 17 ядер `karabas-go-core-*`. Версии сравнивались после нормализации (CRLF и пробелы в концах строк убраны).

| Модуль | Версий | Эталон и замечания |
|---|---|---|
| `mcu.vhd` | **16 на 17 ядер** (одинаковы только alf и alf128) | nanomig: 660 строк, burst, IOCTL, IMG_*, CAPS. Больше всего функций у tsconf: PS/2 и XT-сканкоды, UART с DLM/DLL, DEBUG, matrix и peaks. |
| `spi_slave.vhd` | 3 | nanomig: исправлен `di_req` в idle. next186 — своя версия. Остальные 15 ядер одинаковы и без исправления. |
| `burst_rx.vhd` | 1 | Одинаков в 7 ядрах (alf, alf128, nanomig, nes, profi, rk86, tsconf). |
| `hid_parser.vhd` | 10 | Своя логика в каждом ядре: матрица ZX, NES, ALF, RK86; в tsconf и baseconf к нему прикручен RTC. В nanomig вместо него `hid_amiga.v`. |
| `soft_switches` | 9 (7 VHDL, 2 Verilog) | Механизм один (регистр по `cmd[15:8]`), различается раскладка. В nanomig код встроен в top. |
| `overlay.vhd` | **13** | nanomig и tsconf: RGB 24 бита, HS/VS, автомасштаб; в nanomig есть `H/V_OFFSET`. profi и next: 9-битный вход, свой тайминг. В старых ядрах используется coregen `osd_vram` / `rom_font`. |
| `zhdmi_top.v` | 5 | `ds80` (nanomig, profi); `clk_ref` + мультиплексор FT812 (tsconf, menu, baseconf, vt100); `CLKRATE` (spec256, next186). |
| `zhdmi_tx.vhd` | 3 | nanomig, profi и next186 переключаются на DVI при `audio_en=0`; в spec256 есть `FORCE_DVI`. Остальные файлы `zhdmi_*` одинаковы. |
| `hdmi_pll.v` | 10 | По сути это частоты конкретного ядра. |
| `audio_samplerate.v` | 3 | |
| `pll_reset.v` | 2 | |
| `dpram.v` | 5 | Двухтактная версия есть только в pdp2026. Во всех версиях `mem[0:NUMWORDS]`, то есть на одно слово больше нужного. |
| `fifo.v` | 2 | В alf, alf128, nes, test, next и profi есть ещё coregen `ipcore_dir/fifo.v`. |
| `pcm5102.v` | 4 | Индекс `r2c[16 - …]` даёт 16 при ширине `[15:0]`. Проверить тестбенчем: ошибка это или намеренная задержка I2S. |
| `dac.vhd`, `dvi*.vhd` | 1 | Одинаковы везде. |
| `cursor.vhd` | 5 | |
| `usb_ps2_lut`, `hid_typematic`, `serial_mouse_convertor`, `dot_matrix` | по 2 | |
| `audio_peaks.v`, `audio_filter.v`, `img_sdc.v` | 1 | Есть только в nanomig, почти не зависят от Amiga. |
| UCF-распиновка | 3–4 на плату | Отличается в основном количеством пинов, а не их привязкой. |

**Главный вывод.** Исправления надёжности SPI-линка есть только в nanomig:
1. фильтр коротких импульсов на CS (3 такта) в top;
2. `spi_ssel` закрыт во время burst;
3. слово из очереди берётся по `do_valid`, а не по `di_req`;
4. исправлен `di_req` в idle в `spi_slave`.

Ядра с burst (tsconf, profi, alf, alf128, nes, rk86) подвержены тем же потерям кадров.

**Мелочи:**
- В firmware (`src/config.h`) `0x09` — это `CMD_SPI_CONTROL`. baseconf, menu, tsconf, vt100 и next186 объявляют под этим кодом `CMD_FT`/`CMD_FT_DATA` (`0x09`/`0x0A`). Совместимость нужно проверить.
- Загрузчиков три поколения: ROMLOAD (`06`–`08`), FILELOAD (`0C`–`0E`), IOCTL (`50`–`55`).
- В next есть свои `dpram.vhd`, `spi_master.vhd` и `dac.vhd` в `zxnext/`. Общие модули с такими же именами столкнутся с ними в библиотеке `work`.
- alf и alf128 указывают на один remote.
- pdp2026 лежит в чужом репозитории (tsybulin): изменения туда только через PR.
- У baseconf и vt100 нет remote.

## 2. Принципы

1. **В общий репозиторий идёт только то, что не зависит от машины**: линк с MCU, память, аудио- и видеовыход, OSD, разбор HID до уровня событий, файловый монтировщик. Раскладки клавиатуры, назначение soft switches и PLL ядра остаются в ядрах, общий модуль только параметризуется.
2. **Префикс `kg_` у всех модулей.** Так не будет столкновений с `zxnext/*`, coregen и апстримом (Minimig, TS-Conf).
3. **Verilog-2001 под XST**: без деклараций в неименованных блоках, без `'1`, без `` `default_nettype none `` и без SystemVerilog.
4. **Ненужное выключается параметрами `ENABLE_*` через `generate`**, а не обрезается при map. Это важно для ядер на 96–99% slice.
5. **Сторонний VHDL (zhdmi, TMDS) на Verilog сразу не переписываем.** Он рабочий и одинаковый во всех ядрах. Свои модули переписываем.
6. **Без coregen.** Память, FIFO и PLL пишутся в RTL или инстанцируют примитивы Spartan-6 напрямую.

## 3. Структура репозитория

```
karabas-go-modules/
  rtl/
    mcu/    kg_mcu.v            — совместимая обёртка (порты как у mcu.vhd nanomig)
            kg_mcu_link.v       — spi_slave + burst_rx + фильтр CS + очередь TX + шина кадров
            kg_spi_slave.v      kg_burst_rx.v   kg_cs_deglitch.v
            kg_mcu_cmds.vh      — коды команд, сверенные с firmware src/config.h
            kg_mcu_ctl.v        — SWITCHES, OSD, HW_SETUP, INIT_*/BUSY, CAPS, BTNS, CONTROL (FT/SD2)
            kg_mcu_hid.v        — KBD, MOUSE, JOY, PS2_SCANCODE
            kg_mcu_loader.v     — ROMBANK/ROMDATA/ROMLOADER + FILE* + IOCTL* (одна шина записи)
            kg_mcu_rtc.v        — dpram RTC + отправка CMD_RTC
            kg_mcu_uart.v       kg_mcu_debug.v   kg_mcu_matrix.v
            kg_mcu_img.v        — IMG_* (file mounter)   kg_img_sdc.v
    hid/    kg_hid_keys.v       — отчёт USB → события press/release (код + модификаторы)
            kg_joy_map.v        — Kempston/Sinclair/Cursor/… по JOY_TYPE
            kg_usb_ps2.v (+lut) kg_ps2_typematic.v   kg_cursor.v
            kg_kempston_mouse.v kg_serial_mouse.v
            keymaps/            — таблицы ZX-матрицы, Amiga и т.д.
    ctl/    kg_soft_switches.v  — N 8-битных регистров, плоский выход + строб изменения
    mem/    kg_dpram.v  kg_dpram_2clk.v  kg_fifo.v  kg_async_fifo.v
            kg_spram.v  kg_sprom.v  kg_sdpram.v  kg_tdpram.v  kg_tdpram_asym.v  kg_dist_sdpram.v  kg_dist_spram.v
    clk/    kg_pll.v (PLL_BASE + BUFG)  kg_dcm.v (DCM_SP)  kg_pll_reset.v
    audio/  kg_pcm5102.v  kg_sigma_delta_dac.v  kg_audio_peaks.v  kg_audio_lpf.v
    video/  hdmi/ (zhdmi_*.vhd как есть, kg_hdmi_top.v, kg_hdmi_pll.v, kg_audio_samplerate.v, kg_video_mux.v)
            osd/  kg_osd_overlay.v  kg_pix_doubler.v
  boards/   go/ mini/ minig/  — pins.ucf (только LOC/IOSTANDARD), шаблон top
  prj/      kg_modules.prj    — список файлов, пути от корня репозитория
  sim/      модели (MCU firmware, SDRAM, SRAM), тестбенчи, run-скрипты (ISim + iverilog)
  tools/    coe2hex.py, генерация prj
  docs/     соответствие команд firmware docs/protocol.md, CHANGELOG
```

### Подключение к ядрам

- Git submodule в `<core>/modules`: каждое ядро зафиксировано на своём коммите, сборки воспроизводимы. Соседний checkout через symlink (как сейчас с karabas-go-tools в nanomig) для RTL не годится.
- XST-prj не умеет include. `build_*.sh` склеивает `core.prj` и `modules/prj/kg_modules.prj`, подставляя префикс пути.
- В `.xise` пути относительные (`../modules/rtl/...`).
- ngdbuild принимает несколько `-uc`: `modules/boards/<board>/pins.ucf` плюс `timing.ucf` самого ядра.

## 4. Рефакторинг mcu

`mcu.vhd` сейчас монолит, и в каждом ядре у него свой набор портов. Его стоит разбить на два слоя.

**Слой 1: `kg_mcu_link`.** SPI-slave, burst-приёмник, фильтр CS, очередь TX 512×24 и NOPE против опустошения очереди.
- Выход — шина кадров `rx_stb, rx_cmd[7:0], rx_addr[7:0], rx_data[7:0]` и burst `bst_stb, bst_type, bst_addr[31:0], bst_data`.
- Вход TX — арбитр на K портов `req / data[23:0] / ack` с фиксированным приоритетом (сейчас это цепочка `elsif`).
- Сюда входят все четыре исправления из nanomig и параметр `BURST_MAX_MHZ`.

**Слой 2: декодеры функций.** Каждый слушает шину кадров и, если ему нужно отвечать (`ctl` → CAPS, `rtc`, `uart`, `img`, `matrix` / peaks), подключается к TX. CAPS собирается автоматически из включённых `ENABLE_*`.

**`kg_mcu` — совместимая обёртка** с параметрами `ENABLE_MOUSE`, `ENABLE_RTC`, `ENABLE_UART`, `ENABLE_IMG`, `ENABLE_IOCTL`, `ENABLE_FILELOAD`, `ENABLE_FT`, `ENABLE_SD2`, `ENABLE_PS2`, `ENABLE_DEBUG`, `ENABLE_MATRIX`, `ENABLE_BURST`.
- Порты — надмножество портов nanomig и tsconf, имена те же. В top меняется только имя модуля.
- Отдельные декодеры можно ставить и без обёртки.

**Что меняется по пути:**
- Три загрузчика сводятся в `kg_mcu_loader` с одной шиной записи: `ld_wr, ld_addr[31:0], ld_data, ld_target{rom,file,ioctl}` и `ioctl_slot/size/ext/active`. Нужно сохранить семантику `ROMLOAD_WR` по смене адреса и `ioctl_wr` на каждый байт (см. комментарии в nanomig `mcu.vhd`).
- Портов `buffer` не будет, поэтому `mcu_sim_wrap.py` больше не нужен.
- `MS_UPD` как toggle остаётся в совместимой обёртке, в новых модулях вместо него строб.
- Константы команд — в `kg_mcu_cmds.vh`, сверенном с `config.h`. В firmware добавить ссылку на этот файл.

**Тонкое место — `spi_slave`.** Сдвиговый регистр работает в домене SCK, потому что burst идёт на 32 МГц при `clk_sys` около 28 МГц, и пересэмплирование невозможно. Порт на Verilog обязан сохранить эту архитектуру: сдвиг по SCK, слово передаётся через toggle и синхронизатор.

## 5. Остальные модули

- **soft_switches** → `kg_soft_switches #(.N(32), .INIT(...))` с выходом `regs[N*8-1:0]` и стробом `upd`. Ядро нарезает поля через `assign`. Обработку повтора команды (`prev_command`) сохранить.
- **hid_parser** делится на две части:
  - `kg_hid_keys`: сравнение отчётов, debounce 200 мкс, интервал между событиями, как в `hid_amiga`;
  - раскладку ядра: таблицу или ROM вида «USB-код → матрица ZX, Amiga и т.д.».

  Для ZX-ядер (profi, tsconf, baseconf, spec256, test) можно сделать общий `kg_zx_keymatrix`. NES, ALF и RK86 сохраняют свои раскладки. `kg_joy_map` один для всех. JOY 13 бит; у next и test 12 бит дополняются нулём.
- **overlay**: эталон — nanomig (RGB 24 бита, HS/VS, автомасштаб, `H/V_OFFSET`). К нему добавляются `DEFAULT` из menu и `OSD_ACT` из rk86. Для profi и next (9-битный вход) — отдельный переходник, или они пока остаются в ядре.
- **HDMI**: `kg_hdmi_top` на `zhdmi_tx` из nanomig (DVI-fallback) плюс `FORCE_DVI` из spec256.
  - Режим частоты задаётся параметром `CLK_MODE`: `ds80`, фиксированный `CLKRATE` или вход `freq`.
  - Мультиплексор FT812 (`ft_rgb/ft_sel`) выносится в `kg_video_mux`.
  - `hdmi_pll` получает параметры, а 10 версий превращаются в таблицу значений в ядрах.
- **pcm5102** → `kg_pcm5102` с параметром делителя и сбросом. Сначала тестбенч на формат I2S, потом исправление индекса.
- **dpram**: исправить размер массива, добавить `kg_dpram_2clk` (из pdp2026).
- **fifo** → `kg_fifo` (уже на Verilog). Coregen-fifo заменить с проверкой ресурсов.
- В общие уходят модули из nanomig:
  - `audio_peaks` (уровни для firmware нужны всем ядрам);
  - `audio_filter` → `kg_audio_lpf` с параметром среза;
  - `img_sdc` (монтировщик образов пригодится tsconf и profi).

## 6. Отказ от ipcore (coregen)

### Что используется в сборке (prj / xise)

| Ядро | ipcore | Где используется |
|---|---|---|
| test | `queue`, `rtc`, `pllx5`, `pll` | `mcu.vhd`, top |
| pcxt | `queue`, `rtc` | `mcu.vhd` |
| vt100 | `osd_vram`, `rom_font`, `pll` | `overlay.vhd`, `vt_top.v` |
| alf, alf128 | `osd_vram`, `rom_font`, `pllx5`, `framebuffer` (SDP 64K×6) | `overlay*.vhd`, top, `vga.vhd` |
| nes | то же + `nes_clk`, `ram2k`, `ram8k` (SP) | `memorycontroller.v` |
| rk86 | `osd_vram`, `rom_font`, `queue`, `pll`, `pllx5`, `font` (ROM, coe), `rambuffer` (TDP 256K×1) | `rk_video.v` |
| pdp2026 | `pll`, `bootrom`, `ledfont` (ROM, coe), `sectorbuf` (TDP 256×16) | `pdp2011.v`, `sdspi.v`, `icons.v` |
| next | `queue`, `rtc`, `pll_midi` (DCM), `sdpbram_16k_8` (ENB), distributed `sdpram_128_8`, `sdpram_16_9`, `sdpram_64_9`, `spram_320_9`, `keyjoy_sdpram_64_6` (coe) | `mcu.vhd`, `zxnext/video/*`, `uart.vhd`, `membrane_stick.vhd` |
| next186 | `dcm`, `dcm_dsp`, `cache` (TDP 32×4096, ENB), `DAC_SRAM` (TDP 8/32), `datamem16` (SDP 32/16), `instrmem`, `sr_font` (coe), async FIFO `fifo` (16→32), `sndfifo` (32×4096, счётчики), `qdsp` (17×16 distributed) | `ddr_186.v`, `DSP32.v`, `vga.v`, `soundwave.v`, `cache_controller.v` |
| baseconf | `fifo`, `fifo2`, `osd_vram`, `pll`, `queue`, `rom_font`, `rtc` — только в устаревших `karabas_go_top.prj` / `karabas_mini_top.prj` | `ipcore_dir` нет, RTL уже на своём `fifo.v`. Вычистить prj. |

В сборке без ipcore: nanomig, profi, tsconf, menu, spec256, sdram-test. В profi остался неиспользуемый `ipcore_dir`.

`UART_8250.v` в next186 лежит в `ipcore_dir`, но это обычный исходник из opencores: просто перенести в `rtl/`. `q1` и `q16` есть в prj next186, но где они создаются, не найдено. Скорее всего, это мусор; проверить.

### Чем заменять

**A. Исчезает само при переходе на общие модули:**
- `queue` (24×512) → `kg_fifo` внутри `kg_mcu_link`;
- `rtc` (SDP 256×8) → `kg_dpram` в `kg_mcu_rtc`;
- `osd_vram` (1K×16), `rom_font` (`osd_font.coe`), `rom_font2` (`icons.coe`) → `kg_osd_overlay`;
- `pllx5` (DCM_SP ×5 для HDMI) → `kg_hdmi_top` / `hdmi_pll`.

**B. Обычная память → универсальные модули `rtl/mem/`:**
- `kg_spram`: `ram2k`, `ram8k`;
- `kg_sprom #(.INIT_FILE)`: `font`, `bootrom`, `ledfont`;
- `kg_sdpram #(.INIT_FILE)` с `en`: `framebuffer`, `sdpbram_16k_8`, `instrmem`;
- `kg_tdpram`: `sectorbuf`, `rambuffer`, `cache` (ENB), `sr_font` (init);
- `kg_dist_sdpram` / `kg_dist_spram` (асинхронное чтение, LUT RAM): `sdpram_*`, `spram_320_9`, `keyjoy_sdpram_64_6`;
- `tools/coe2hex.py`: перевод `.coe` в `.hex` для `$readmemh`.

Латентность совпадает: у этих blk_mem_gen выходные регистры выключены, то есть чтение за 1 такт.

**C. Сложные случаи (next186):**
- Асимметричная ширина (`DAC_SRAM` 8/32, `datamem16` 32/16): память на широкое слово с byte-enable и мультиплексором. Если не уложится — явный `RAMB16BWER` в `kg_tdpram_asym`.
- Async FIFO (`fifo` 16→32, `sndfifo`, `qdsp`): `kg_async_fifo` с Gray-указателями, соотношением ширин и счётчиками rd/wr, плюс TIG/DATAPATHONLY на синхронизаторы. Обязательны тестбенч с разными частотами и проверка на железе.

**D. PLL и DCM.** «MMCM» в `.xco` — просто метка, внутри сгенерированных `.v` стоят `PLL_BASE` / `DCM_SP`. Их можно заменить один к одному на `kg_pll` / `kg_dcm`, перенеся коэффициенты из текущих `.v`. Например, у alf `pll`: `DIVCLK=2, MULT=37, OUT=11/116/58/77`.

**E. Уборка.** Удалить неиспользуемые `ipcore_dir` и устаревшие prj baseconf. После этого симуляции не нужна XilinxCoreLib.

### Проверка каждой замены
1. Число RAMB16/RAMB8, LUT RAM и DCM/PLL в `_map.mrp` до и после. Если выведенная память ушла в LUT, ищи асинхронное чтение или лишние порты.
2. Тестбенч модуля против поведенческой модели coregen (из `ipcore_dir/*.v`, пока она есть).
3. Проверка на железе и timing report: констрейнты на сгенерированные клоки должны сохраниться.

## 7. Этапы

0. **Скелет репозитория.** Перенести версии из nanomig как есть: без переименований и правок, VHDL остаётся VHDL. Перевести nanomig на submodule. Критерий: та же утилизация в `_map.mrp`, тайминги выполнены, `nanomig.kg3` работает на железе. Сразу добавить простые модули из 6.B и 6.D (`kg_spram`, `kg_sprom`, `kg_sdpram`, `kg_tdpram`, `kg_dist_*`, `kg_pll`, `kg_dcm`) и `coe2hex.py`.
1. **Тесты.** Перенести тестбенчи nanomig как регрессию модулей (`run_img_sim`, `run_hid_sim`, `run_audio_sim`, модель firmware). Добавить тестбенч линка с моделью MCU: кадры, burst, иголки на CS, CAPS. CI на GitHub Actions для Verilog: iverilog + `verilator --lint-only`.
2. **Переписать на Verilog листовые модули**: `spi_slave`, `burst_rx`, `dac`, `soft_switches`, `cursor`, `pix_doubler`, `overlay`. Эквивалентность проверять в смешанном ISim: один стимул на старый VHDL и новый Verilog, сравнение выходов по тактам.
3. **mcu**: слои, декодеры, обёртка `kg_mcu`. Проверка против `mcu.vhd` nanomig, затем tsconf (PS/2, XT, UART) и rk86 / spec256 (IOCTL).
4. **Перевод ядер по одному.** На железе каждый раз проверять загрузку ROM, OSD, клавиатуру, джойстики, HDMI со звуком. Порядок:
   1. nanomig;
   2. profi;
   3. tsconf, baseconf;
   4. test, pcxt, vt100 (в основном ipcore группы A);
   5. alf, alf128, nes, rk86 (исправления линка + ipcore A, B, PLL);
   6. menu (загрузчик, рисковать им в последнюю очередь);
   7. spec256, sdram-test;
   8. pdp2026 (PR автору);
   9. next (VHDL top, своя раскладка, distributed RAM ZX Next с пометками `// karabas:`);
   10. next186 (асимметричная память, async FIFO).
5. **Документация.** Обновить CLAUDE.md nanomig (сейчас там «copies from profi»). Вести CHANGELOG, ставить теги `vX.Y`. Изменение портов — major-версия; совместимая обёртка живёт как минимум один major.

## 8. Риски

- **Ресурсы и тайминги.** nanomig на 96–99% slice, у Go-сборки slack 0.35 нс. После каждого переноса сравнивать LUT и slack, а `ENABLE_*` должны реально выключать логику.
- **Совместимость с firmware**: конфликт `0x09` и старые FT-команды. Проверить до этапа 3.
- **Двойная фильтрация CS.** Фильтр CS и `MCU_IO[...]` сейчас в top. После переноса в `kg_mcu_link` не фильтровать дважды.
- **Async FIFO и асимметричная память** — единственные модули, которые нельзя проверить простым сравнением с coregen. Нужны отдельные тесты и проверка на железе.

## Открытые решения

- Submodule или соседний checkout. Рекомендация: submodule.
- Префикс `kg_`. Рекомендация: да.
- Переписывать ли zhdmi на Verilog. Рекомендация: позже, отдельно, когда появятся тесты.
