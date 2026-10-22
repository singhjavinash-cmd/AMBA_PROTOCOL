
#!/bin/bash
set -e

echo "===== AMBA PROTOCOL REGRESSION ====="

echo "[1/4] APB Valid Assertion Test"
iverilog -g2012 -Wall -s tb_apb_sva_valid -o sim_apb_valid \
tb/apb_sva.sv tb/tb_apb_sva_valid.sv
vvp sim_apb_valid

echo "[2/4] APB Self-Checking Test"
iverilog -g2012 -Wall -s tb_apb_self_checking -o sim_apb_self \
rtl/apb_slave.sv tb/apb_sva.sv tb/tb_apb_self_checking.sv
vvp sim_apb_self

echo "[3/4] AXI Bridge Test"
iverilog -g2012 -Wall -s tb_axi_bridge -o sim_bridge \
rtl/apb_slave.sv rtl/axi_to_apb_bridge.sv tb/tb_axi_bridge.sv
vvp sim_bridge

echo "[4/4] Multi-Slave Test"
iverilog -g2012 -Wall -s tb_multislave_subsystem -o sim_multislave \
rtl/apb_slave.sv rtl/apb_timer.sv rtl/axi_to_apb_bridge.sv \
tb/apb_sva.sv tb/tb_multislave_subsystem.sv
vvp sim_multislave

echo "===== ALL TESTS COMPLETED ====="
