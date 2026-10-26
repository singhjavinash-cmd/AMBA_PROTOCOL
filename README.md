# AMBA AXI4-Lite to APB4 Bridge with Memory and Timer Peripherals

## Project Overview

This project implements an AMBA AXI4-Lite to APB4 protocol bridge using SystemVerilog RTL. It connects an AXI4-Lite interface to an APB-based peripheral subsystem containing memory and timer peripherals.

The project focuses on protocol conversion, memory-mapped read and write transactions, byte-level write strobes, peripheral integration, and simulation-based functional verification.

## Architecture

```text
       AXI4-Lite Master
               |
               v
    +-----------------------+
    | AXI4-Lite to APB4     |
    | Bridge                |
    +-----------------------+
               |
               v
    +-----------------------+
    | APB Subsystem         |
    | Address Decoding      |
    +-----------------------+
          |           |
          v           v
     +---------+  +---------+
     | Memory  |  | Timer   |
     | Slave   |  | Peripheral
     +---------+  +---------+
```

## Key Features

- AXI4-Lite to APB4 protocol bridging.
- Independent AXI write-address and write-data capture.
- AXI read and write response handling.
- APB setup and access phases with wait-state support.
- Byte-level write support using AXI `WSTRB` and APB `PSTRB`.
- Memory-mapped memory and timer peripherals.
- Error responses for unmapped addresses.
- SystemVerilog RTL and self-checking testbenches.
- SystemVerilog Assertions (SVA) test infrastructure.
- Waveform-based simulation debugging.

## Technology Stack

- SystemVerilog
- RTL design and simulation
- AXI4-Lite and APB4 protocols
- Self-checking testbenches
- SystemVerilog Assertions
- Git and GitHub

## Verification Results

The latest recorded regression output reported:

- All 6 test suites passed.
- Integrated subsystem test: 12 checks passed.
- Randomized AXI byte-write test: 100 transactions checked.
- Readback passes: 100.
- Readback failures: 0.
- Unmapped-address error response tested.
- Waveform screenshots included under `docs/images/`.

These results reflect the recorded simulation run; they do not by themselves establish complete AMBA protocol compliance or formal verification.

## Repository Structure

```text
amba_apb_project/
├── rtl/
│   ├── axi_to_apb_bridge.sv
│   ├── apb_slave.sv
│   ├── apb_timer.sv
│   └── apb_subsystem.sv
├── tb/
│   ├── tb_axi_bridge.sv
│   ├── tb_axi_random.sv
│   ├── tb_apb.sv
│   ├── tb_apb_self_checking.sv
│   ├── tb_apb_subsystem.sv
│   ├── tb_multislave_subsystem.sv
│   └── apb_sva.sv
├── docs/
│   └── images/
├── run_all.sh
└── README.md
```

## How to Run

Run the regression script from the project root:

```bash
bash run_all.sh
```

The script executes the configured simulation test suites. A successful run should report that all configured test suites passed.

## Waveform Results

Waveform screenshots are available in `docs/images/`:

- `axi_apb_waveform_page_1.png`
- `axi_apb_waveform_page_2.png`
- `axi_bridge_waveform.png`
- `multislave_waveform.png`

## Learning Outcomes

- Understanding AXI4-Lite read and write handshakes.
- Understanding APB setup and access timing.
- Designing finite-state machines for protocol conversion.
- Implementing byte-enabled memory writes.
- Integrating memory-mapped peripherals.
- Writing self-checking SystemVerilog testbenches.
- Debugging RTL through simulation waveforms.

## Future Improvements

- Expand protocol assertions and corner-case verification.
- Verify response backpressure and reset during active transfers.
- Add lint and synthesis checks using available EDA tools.
- Improve functional coverage and verification documentation.
- Explore integration with additional AMBA bus components.

## Project Scope

This project focuses on an AXI4-Lite to APB4 bridge and a peripheral subsystem. It is not a complete implementation of every AMBA protocol.
