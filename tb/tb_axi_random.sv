
`timescale 1ns/1ps

module tb_axi_random;

    logic clk = 0;
    logic resetn = 0;

    logic [31:0] awaddr, wdata, araddr;
    logic awvalid, awready;
    logic wvalid, wready;
    logic [3:0] wstrb;
    logic [1:0] bresp;
    logic bvalid, bready;

    logic arvalid, arready;
    logic [31:0] rdata;
    logic [1:0] rresp;
    logic rvalid, rready;

    logic [31:0] paddr, pwdata, prdata;
    logic [3:0] pstrb;
    logic psel, penable, pwrite, pready, pslverr;

    logic [31:0] expected_mem [0:15];
    logic [31:0] addr, data, expected, actual;

    logic [3:0] strb;
    integer i, lane;
    integer passed, failed;

    always #5 clk = ~clk;

    // AXI4-Lite to APB4 Bridge
    axi_to_apb_bridge dut (
        .clk             (clk),
        .resetn           (resetn),

        .s_axi_awaddr     (awaddr),
        .s_axi_awvalid    (awvalid),
        .s_axi_awready    (awready),

        .s_axi_wdata      (wdata),
        .s_axi_wstrb      (wstrb),
        .s_axi_wvalid     (wvalid),
        .s_axi_wready     (wready),

        .s_axi_bresp      (bresp),
        .s_axi_bvalid     (bvalid),
        .s_axi_bready     (bready),

        .s_axi_araddr     (araddr),
        .s_axi_arvalid    (arvalid),
        .s_axi_arready    (arready),

        .s_axi_rdata      (rdata),
        .s_axi_rresp      (rresp),
        .s_axi_rvalid     (rvalid),
        .s_axi_rready     (rready),

        .m_apb_paddr      (paddr),
        .m_apb_psel       (psel),
        .m_apb_penable    (penable),
        .m_apb_pwrite     (pwrite),
        .m_apb_pwdata     (pwdata),
        .m_apb_pstrb      (pstrb),
        .m_apb_prdata     (prdata),
        .m_apb_pready     (pready),
        .m_apb_pslverr    (pslverr)
    );

    // APB memory slave
    apb_slave mem (
        .pclk     (clk),
        .presetn  (resetn),
        .paddr    (paddr),
        .psel     (psel),
        .penable  (penable),
        .pwrite   (pwrite),
        .pwdata   (pwdata),
        .pstrb    (pstrb),
        .prdata   (prdata),
        .pready   (pready),
        .pslverr  (pslverr)
    );

    // AXI write transaction
    task automatic axi_write(
        input logic [31:0] a,
        input logic [31:0] d,
        input logic [3:0]  s
    );
        begin
            // Write address channel
            @(negedge clk);
            awaddr  = a;
            awvalid = 1'b1;

            do @(posedge clk);
            while (awready !== 1'b1);

            @(negedge clk);
            awvalid = 1'b0;

            // Write data channel
            wdata  = d;
            wstrb  = s;
            wvalid = 1'b1;

            do @(posedge clk);
            while (wready !== 1'b1);

            @(negedge clk);
            wvalid = 1'b0;

            // Write response channel
            do @(posedge clk);
            while (bvalid !== 1'b1);

            if (bresp !== 2'b00)
                $fatal(1, "Write BRESP error: %b", bresp);

            // Accept response
            @(negedge clk);
            bready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            bready = 1'b0;
        end
    endtask

    // AXI read transaction
    task automatic axi_read(
        input  logic [31:0] a,
        output logic [31:0] d
    );
        begin
            @(negedge clk);
            araddr  = a;
            arvalid = 1'b1;

            do @(posedge clk);
            while (arready !== 1'b1);

            @(negedge clk);
            arvalid = 1'b0;

            do @(posedge clk);
            while (rvalid !== 1'b1);

            d = rdata;

            if (rresp !== 2'b00)
                $fatal(1, "Read RRESP error: %b", rresp);

            // Accept read response
            @(negedge clk);
            rready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            rready = 1'b0;
        end
    endtask

    // Main test
    initial begin
        $dumpfile("axi_random.vcd");
        $dumpvars(0, tb_axi_random);

        passed = 0;
        failed = 0;

        awaddr  = 0;
        awvalid = 0;
        wdata   = 0;
        wstrb   = 0;
        wvalid  = 0;
        bready  = 0;

        araddr  = 0;
        arvalid = 0;
        rready  = 0;

        for (i = 0; i < 16; i = i + 1)
            expected_mem[i] = 32'h0000_0000;

        repeat (3) @(negedge clk);
        resetn = 1'b1;
        repeat (2) @(negedge clk);

        $display("");
        $display("======================================");
        $display(" Randomized AXI4-Lite Write/Read Test");
        $display("======================================");

        // 100 randomized writes followed by readback checks
        for (i = 0; i < 100; i = i + 1) begin

            // Generate aligned address, random data and nonzero strobe
            addr = $urandom_range(0, 15) * 4;
            data = $urandom;
            strb = $urandom_range(1, 15);

            axi_write(addr, data, strb);

            // Update reference model for enabled byte lanes
            for (lane = 0; lane < 4; lane = lane + 1) begin
                if (strb[lane]) begin
                    expected_mem[addr >> 2][lane*8 +: 8]
                        = data[lane*8 +: 8];
                end
            end

            // Read back and compare
            axi_read(addr, actual);
            expected = expected_mem[addr >> 2];

            if (actual === expected) begin
                passed = passed + 1;
            end
            else begin
                failed = failed + 1;

                $display(
                    "[FAIL] Iter=%0d Addr=%h WSTRB=%b Expected=%h Actual=%h",
                    i, addr, strb, expected, actual
                );
            end
        end

        $display("");
        $display("======================================");
        $display("Random transactions checked: %0d", 100);
        $display("Readback PASS: %0d", passed);
        $display("Readback FAIL: %0d", failed);
        $display("======================================");

        if (failed == 0)
            $display("RANDOMIZED AXI TEST PASSED");
        else
            $fatal(1, "RANDOMIZED AXI TEST FAILED");

        $finish;
    end

    // Global timeout
    initial begin
        #2000000;
        $fatal(1, "Random test timeout");
    end

endmodule
