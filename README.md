# AMBA AXI4-Lite to APB Bridge

A SystemVerilog-based AMBA protocol project implementing an **AXI4-Lite to APB bridge** with memory and timer peripherals. The project focuses on protocol conversion, transaction handling, byte-level write support, and simulation-based verification.

## Overview

The bridge converts AXI4-Lite read and write transactions into APB transfers. It coordinates AXI address, data, and response channels with APB setup and access phases.

### Architecture

```mermaid
flowchart LR
    A[AXI4-Lite Master] <--> B[AXI4-Lite to APB Bridge]
    B <--> C[APB Interconnect]
    C <--> D[APB Memory Slave]
    C <--> E[APB Timer]
    C --> F[Unmapped Address Response]
```

## Key Features

- AXI4-Lite to APB protocol conversion.
- Independent AXI write-address and write-data handshakes.
- Read and write response handling.
- AXI `WSTRB` to APB `PSTRB` propagation.
- Byte-level write support for memory and timer registers.
- APB wait-state handling.
- Memory and timer peripheral integration.
- Error responses for unmapped addresses.
- SystemVerilog-based testbenches and APB protocol checks.

## Project Structure

```text
AMBA_PROTOCOL/
├── rtl/
│   ├── axi_to_apb_bridge.sv
│   ├── apb_slave.sv
│   └── apb_timer.sv
├── tb/
│   ├── apb_sva.sv
│   ├── tb_apb.sv
│   ├── tb_apb_self_checking.sv
│   ├── tb_apb_sva_valid.sv
│   ├── tb_axi_bridge.sv
│   └── tb_multislave_subsystem.sv
├── docs/
│   └── images/
├── run_all.sh
└── README.md
```

## Verification

The project includes a regression script that runs four simulation suites:

1. APB valid-transaction assertion test.
2. APB self-checking test.
3. AXI bridge test.
4. Multi-slave subsystem test.

### Latest observed results

- Multi-slave subsystem: **6/6 tests passed**.
- Memory write and read: PASS.
- Timer enable write and counter read: PASS.
- Unmapped write and read error responses: PASS.
- Regression script: `ALL TESTS COMPLETED`.

These results reflect the latest simulation output observed during development. Run the regression again after making further changes.

## Run the Regression

### Requirements

- Icarus Verilog (`iverilog` and `vvp`)
- Bash-compatible terminal
- Git

### Execute

Clone the repository and enter the project directory:

```bash
git clone https://github.com/singhjavinash-cmd/AMBA_PROTOCOL.git
cd AMBA_PROTOCOL
```

Run the regression:

```bash
chmod +x run_all.sh
./run_all.sh
```

## Waveforms

Waveform images are available in [`docs/images/`](docs/images/). The simulation testbenches also generate VCD waveform files, which can be inspected using GTKWave.

## Technologies

- SystemVerilog
- AMBA AXI4-Lite
- AMBA APB
- Icarus Verilog
- Git and GitHub

## Future Improvements

- Add directed tests for partial-byte writes using different `WSTRB` patterns.
- Add randomized AXI transaction testing.
- Improve assertion reporting and eliminate simulator synthesis warnings.
- Add functional coverage and automated regression summaries.
- Document timing diagrams for AXI-to-APB read and write transfers.

## Repository

GitHub: https://github.com/singhjavinash-cmd/AMBA_PROTOCOL
