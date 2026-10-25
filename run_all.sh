
#!/bin/bash
set -e

echo "======================================"
echo " AXI4-Lite to APB Subsystem Regression"
echo "======================================"

echo "[1/6] APB Valid Assertion Test"
iverilog -g2012 -Wall -s tb_apb_sva_valid -o sim_apb_valid \
    tb/apb_sva.sv tb/tb_apb_sva_valid.sv
vvp sim_apb_valid

echo "[2/6] APB Self-Checking Test"
iverilog -g2012 -Wall -s tb_apb_self_checking -o sim_apb_self \
    rtl/apb_slave.sv tb/apb_sva.sv tb/tb_apb_self_checking.sv
vvp sim_apb_self

echo "[3/6] AXI Bridge Test"
iverilog -g2012 -Wall -s tb_axi_bridge -o sim_bridge \
    rtl/apb_slave.sv rtl/axi_to_apb_bridge.sv tb/tb_axi_bridge.sv
vvp sim_bridge

echo "[4/6] Multi-Slave Test"
iverilog -g2012 -Wall -s tb_multislave_subsystem -o sim_multislave \
    rtl/apb_slave.sv rtl/apb_timer.sv rtl/axi_to_apb_bridge.sv \
    tb/apb_sva.sv tb/tb_multislave_subsystem.sv
vvp sim_multislave

echo "[5/6] Randomized AXI Byte-Write Test"
iverilog -g2012 -Wall -s tb_axi_random -o sim_axi_random \
    rtl/apb_slave.sv rtl/axi_to_apb_bridge.sv tb/tb_axi_random.sv
vvp sim_axi_random

echo "[6/6] Integrated AXI-to-APB Subsystem Test"
iverilog -g2012 -Wall -s tb_apb_subsystem -o sim_apb_subsystem \
    rtl/apb_slave.sv rtl/apb_timer.sv rtl/axi_to_apb_bridge.sv \
    rtl/apb_subsystem.sv tb/apb_sva.sv tb/tb_apb_subsystem.sv
vvp sim_apb_subsystem

echo "======================================"
echo " ALL 6 TEST SUITES PASSED"
echo "======================================"
