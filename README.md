# AMBA Protocol Interconnect: AXI4-Lite/APB and AHB-Lite/APB

A SystemVerilog learning project demonstrating protocol bridges and APB peripherals. The repository contains an AXI4-Lite-to-APB path and an AHB-Lite-to-APB path, with simulation testbenches.

> Scope note: this is a project implementation and simulation exercise, not a claim of complete AMBA-family implementation or formal ARM compliance certification.

## Architecture

```text
AXI4-Lite Master
      |
      v
AXI4-Lite-to-APB Bridge
      |
      v
 APB Subsystem -------- APB Memory Slave
      |                 APB Timer
      +---------------- Address/response mux


AHB-Lite Master
      |
      v
AHB-Lite-to-APB Bridge
      |
      v
 APB Address/Response Mux
      |                 |
      v                 v
 APB Memory Slave    APB Timer
```

## AHB-Lite to APB address map

| Address range / address | Peripheral | Behavior |
|---|---|---|
| `0x0000_0XXX` | APB memory | Memory-mapped registers; wait states are supported |
| `0x0000_1XXX` | APB timer | Timer control and counter |
| `0x0000_2000` and other unmapped regions | Error response | Bridge reports an AHB error |

Timer registers exercised by the integrated testbench:

| Address | Register | Use |
|---|---|---|
| `0x0000_1000` | Control | Bit 0 enables the timer |
| `0x0000_1004` | Counter | Reads the running counter |

## Relevant source files

### RTL
- `rtl/ahb_lite_master.sv` — AHB-Lite test master
- `rtl/ahb_lite_slave.sv` — AHB-Lite slave module, if used by the standalone tests
- `rtl/ahb_to_apb_bridge.sv` — AHB-Lite-to-APB bridge
- `rtl/axi_to_apb_bridge.sv` — AXI4-Lite-to-APB bridge
- `rtl/apb_slave.sv` — APB memory peripheral
- `rtl/apb_timer.sv` — APB timer peripheral
- `rtl/apb_subsystem.sv` — APB subsystem integration

### Testbenches
- `tb/tb_ahb_apb_system.sv` — integrated AHB-to-APB system test
- `tb/tb_ahb_to_apb_bridge.sv` — AHB-to-APB bridge test
- `tb/tb_ahb_lite.sv` — AHB-Lite master/slave test, if supported by the local source set
- Existing AXI/APB testbenches — use the exact module/file names present in `tb/`.

## Run the integrated AHB-to-APB system test

From the repository root, run:

```bash
iverilog -g2012 -s tb_ahb_apb_system -o ahb_apb_system_test \
  rtl/ahb_lite_master.sv \
  rtl/ahb_to_apb_bridge.sv \
  rtl/apb_slave.sv \
  rtl/apb_timer.sv \
  tb/tb_ahb_apb_system.sv

vvp ahb_apb_system_test
```

A successful run should end with output similar to:

```text
AHB-to-APB checks = 12
AHB-to-APB errors = 0
ALL AHB-to-APB SYSTEM TESTS PASSED
```

The integrated test checks memory writes/readbacks, timer enable/control readback, timer counter increment, and an unmapped-address error response.

## Waveform evidence

To capture a waveform, add the following near the start of the `initial` test sequence in `tb/tb_ahb_apb_system.sv`, before reset/test activity:

```systemverilog
initial begin
    $dumpfile("ahb_apb_system.vcd");
    $dumpvars(0, tb_ahb_apb_system);
end
```

If the file already has a main `initial begin`, do **not** create a duplicate enclosing block; instead add just the two `$dump...` statements inside that existing block. Alternatively, place them in a separate `initial` block.

Recompile and rerun using the commands above. Open the VCD in GTKWave if installed:

```bash
gtkwave ahb_apb_system.vcd
```

Useful signals to inspect:
- AHB: `HADDR`, `HTRANS`, `HWRITE`, `HREADY`, `HREADYOUT`, `HRESP`
- APB: `PSEL`, `PENABLE`, `PADDR`, `PWRITE`, `PWDATA`, `PRDATA`, `PREADY`, `PSLVERR`
- Test control: `start`, `busy`, `done`, `error`, `rdata`

## GitHub update

Review the changes before committing. From the repository root:

```bash
git status
git add README.md rtl tb
git diff --cached --stat
git commit -m "Document AHB-to-APB integration and simulation"
git push
```

If you only want to commit this documentation and the current testbench changes, stage the exact files instead of all of `rtl` and `tb`, for example:

```bash
git add README.md tb/tb_ahb_apb_system.sv
```

Do not commit generated binaries such as `ahb_apb_system_test` or large waveform files unless you intentionally want to keep waveform evidence in the repository. Consider adding generated files to `.gitignore`.

## Suggested `.gitignore`

```gitignore
*.vcd
*_test
a.out
```

Keep a waveform locally for debugging; if you want to publish a waveform screenshot, save a clear GTKWave screenshot under `docs/images/` and mention what signals it demonstrates.
