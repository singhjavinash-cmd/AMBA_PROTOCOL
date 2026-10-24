# AMBA AXI4-Lite to APB4 Bridge

A SystemVerilog-based AMBA protocol project implementing an **AXI4-Lite to APB4 bridge** with memory and timer peripherals. The project demonstrates protocol conversion, independent AXI channel handshakes, byte-level write support, APB wait-state handling, and simulation-based verification.

## Overview

The bridge converts AXI4-Lite read and write transactions into APB transfers. It coordinates AXI address, data, and response channels with APB setup and access phases.

### Architecture

```mermaid
flowchart LR
    A[AXI4-Lite Master] <--> B[AXI4-Lite to APB4 Bridge]
    B <--> C[APB Interconnect]
    C <--> D[APB Memory Slave]
    C <--> E[APB Timer]
    C --> F[Unmapped Address Error Response]
```

## Key Features

- AXI4-Lite to APB4 protocol conversion.
- Independent AXI write-address and write-data handshakes.
- Read and write response handling with backpressure support.
- AXI `WSTRB` to APB `PSTRB` propagation.
- Byte-level write support for memory and timer registers.
- APB wait-state handling.
- Memory and timer peripheral integration.
- Error responses for unmapped addresses.
- APB protocol checking and self-checking testbenches.
- Randomized AXI byte-write verification.

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
│   ├── tb_apb_sva_check.sv
│   ├── tb_apb_sva_valid.sv
│   ├── tb_axi_bridge.sv
│   ├── tb_axi_random.sv
│   └── tb_multislave_subsystem.sv
├── docs/
│   └── images/
├── run_all.sh
└── README.md
```

## Verification Results

Run `./run_all.sh` to execute the five simulation test suites.

| Test suite | Observed result |
|---|---|
| APB valid assertion test | PASS |
| APB self-checking test | 4 PASS, 0 FAIL |
| AXI bridge test | 8 PASS, 0 FAIL |
| Multi-slave subsystem | 6/6 PASS |
| Randomized AXI byte-write test | 100 PASS, 0 FAIL |

**Latest observed regression result: `ALL 5 TEST SUITES PASSED`.**

The randomized test performed 100 write/read transactions and reported zero readback failures. These results are based on the simulation output observed during development.

## Run the Regression

### Requirements

- Icarus Verilog (`iverilog` and `vvp`)
- Bash-compatible terminal
- Git

### Execute

Clone the repository:

```bash
git clone https://github.com/singhjavinash-cmd/AMBA_PROTOCOL.git
cd AMBA_PROTOCOL
```

Run all test suites:

```bash
chmod +x run_all.sh
./run_all.sh
```

The script compiles and executes the testbenches. A successful run should end with:

```text
===== ALL 5 TEST SUITES PASSED =====
```

## Waveforms

The testbenches generate VCD waveform files that can be inspected using GTKWave. Waveform images are also maintained in `docs/images/`.

## Technologies

- SystemVerilog
- AMBA AXI4-Lite
- AMBA APB4
- Icarus Verilog
- GTKWave
- Git and GitHub

## Future Improvements

- Add functional coverage and more assertion checks.
- Add timing diagrams for AXI-to-APB read and write transfers.
- Expand testing for reset sequences and error conditions.
- Explore synthesis and FPGA implementation using a compatible toolchain.

## Repository

[AMBA_PROTOCOL on GitHub](https://github.com/singhjavinash-cmd/AMBA_PROTOCOL)
