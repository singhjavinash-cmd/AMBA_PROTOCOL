# AXI4-Lite to APB Multi-Slave Interconnect Subsystem

A synthesizable SystemVerilog implementation of an AXI4-Lite to APB protocol bridge with a multi-slave peripheral subsystem.

## Architectural Overview

- **AXI4-Lite Interface:** Supports the five independent AXI4-Lite channels: AW, W, B, AR, and R.
- **Protocol Bridge:** Uses an FSM with `IDLE`, `APB_SETUP`, and `APB_ACCESS` states to control APB transfers and AXI responses.
- **Peripheral Subsystem:**
  - `apb_slave.sv`: APB memory slave with configurable wait-state behavior.
  - `apb_timer.sv`: APB timer peripheral with a counter register.
- **Address Decode:** Routes accesses to the memory and timer regions and returns AXI `SLVERR` (`2'b10`) for unmapped writes, as tested by the current testbench.
- **Verification:** Includes a multi-slave testbench, procedural APB protocol checks, and waveform generation.

## Memory Map

| Peripheral | Address Range | Access |
|---|---|---|
| APB RAM | `0x0000_0000` – `0x0000_0FFF` | Read / Write |
| APB Timer | `0x0000_1000` – `0x0000_1FFF` | Read / Write |
| Unmapped Space | `0x0000_2000` and above | Error response for tested unmapped write |

## Project Structure

```text
amba_apb_project/
├── rtl/
│   ├── apb_slave.sv
│   ├── apb_timer.sv
│   └── axi_to_apb_bridge.sv
├── tb/
│   ├── apb_sva.sv
│   ├── tb_apb_self_checking.sv
│   ├── tb_apb.sv
│   ├── tb_axi_bridge.sv
│   └── tb_multislave_subsystem.sv
├── apb_waveform.vcd
├── multislave.vcd
└── README.md
```

## Tools

- Icarus Verilog (`iverilog`, `vvp`)
- Surfer Waveform Viewer in VS Code (for viewing VCD waveforms)

## Run the Multi-Slave Simulation

Run the following command from the project root:

```bash
iverilog -g2012 -Wall -o sim_multislave \
  rtl/apb_slave.sv \
  rtl/apb_timer.sv \
  rtl/axi_to_apb_bridge.sv \
  tb/apb_sva.sv \
  tb/tb_multislave_subsystem.sv \
  && vvp sim_multislave
```

The testbench generates `multislave.vcd` for waveform inspection.

## Current Verification Results

The current simulation has reported:

- Memory test: PASS for address `0x0004`, data `0xAAAA_BBBB`.
- Timer test: PASS for address `0x1004`, counter value `21`.
- Unmapped write: PASS for `BRESP = 2'b10` (`SLVERR`).

These results describe the tests currently exercised by the testbench; they do not establish complete compliance with every AXI4-Lite or APB specification requirement.

## Waveform Viewing

1. Run the simulation command.
2. Open `multislave.vcd` in Surfer Waveform Viewer in VS Code.
3. Inspect AXI handshakes, APB setup/access phases, peripheral signals, and response status.
