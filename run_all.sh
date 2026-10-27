
#!/bin/bash

set -e

echo "========================================"
echo " AMBA AXI/APB + AHB/APB REGRESSION"
echo "========================================"

# 1. APB basic test
echo ""
echo "[1] APB Basic Test"
iverilog -g2012 -Wall -s tb_apb -o sim_apb \
    rtl/apb_slave.sv tb/tb_apb.sv
vvp sim_apb

# 2. APB self-checking test
echo ""
echo "[2] APB Self-Checking Test"
iverilog -g2012 -Wall -s tb_apb_self_checking -o sim_apb_self \
    rtl/apb_slave.sv tb/apb_sva.sv tb/tb_apb_self_checking.sv
vvp sim_apb_self

# 3. AXI bridge test
echo ""
echo "[3] AXI Bridge Test"
iverilog -g2012 -Wall -s tb_axi_bridge -o sim_bridge \
    rtl/apb_slave.sv rtl/axi_to_apb_bridge.sv tb/tb_axi_bridge.sv
vvp sim_bridge

# 4. AXI multi-slave test
echo ""
echo "[4] Multi-Slave AXI Test"
iverilog -g2012 -Wall -s tb_multislave_subsystem -o sim_multislave \
    rtl/apb_slave.sv rtl/apb_timer.sv rtl/axi_to_apb_bridge.sv \
    tb/apb_sva.sv tb/tb_multislave_subsystem.sv
vvp sim_multislave

# 5. Randomized AXI byte-write test
echo ""
echo "[5] Randomized AXI Byte-Write Test"
iverilog -g2012 -Wall -s tb_axi_random -o sim_axi_random \
    rtl/apb_slave.sv rtl/axi_to_apb_bridge.sv tb/tb_axi_random.sv
vvp sim_axi_random

# 6. Integrated AXI-to-APB subsystem
echo ""
echo "[6] Integrated AXI-to-APB Subsystem Test"
iverilog -g2012 -Wall -s tb_apb_subsystem -o sim_apb_subsystem \
    rtl/apb_slave.sv rtl/apb_timer.sv rtl/axi_to_apb_bridge.sv \
    rtl/apb_subsystem.sv tb/apb_sva.sv tb/tb_apb_subsystem.sv
vvp sim_apb_subsystem

# 7. Standalone AHB-Lite master/slave test
echo ""
echo "[7] AHB-Lite Master/Slave Test"
iverilog -g2012 -Wall -s tb_ahb_lite -o sim_ahb \
    rtl/ahb_lite_master.sv rtl/ahb_lite_slave.sv tb/tb_ahb_lite.sv
vvp sim_ahb

# 8. AHB-to-APB bridge test
echo ""
echo "[8] AHB-to-APB Bridge Test"
iverilog -g2012 -Wall -s tb_ahb_to_apb_bridge -o sim_ahb_bridge \
    rtl/ahb_to_apb_bridge.sv tb/tb_ahb_to_apb_bridge.sv
vvp sim_ahb_bridge

# 9. Integrated AHB-to-APB system test
echo ""
echo "[9] Integrated AHB-to-APB System Test"
iverilog -g2012 -Wall -s tb_ahb_apb_system -o sim_ahb_apb_system \
    rtl/ahb_lite_master.sv rtl/ahb_to_apb_bridge.sv \
    rtl/apb_slave.sv rtl/apb_timer.sv tb/tb_ahb_apb_system.sv
vvp sim_ahb_apb_system

echo ""
echo "========================================"
echo " ALL CONFIGURED TESTS PASSED"
echo "========================================"
