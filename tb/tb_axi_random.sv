
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
    integer i, lane, passed, failed;

    always #5 clk = ~clk;

    axi_to_apb_bridge dut (
        .clk(clk), .resetn(resetn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .m_apb_paddr(paddr), .m_apb_psel(psel),
        .m_apb_penable(penable), .m_apb_pwrite(pwrite),
        .m_apb_pwdata(pwdata), .m_apb_pstrb(pstrb),
        .m_apb_prdata(prdata), .m_apb_pready(pready),
        .m_apb_pslverr(pslverr)
    );

    apb_slave mem (
        .pclk(clk), .presetn(resetn),
        .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .pstrb(pstrb),
        .prdata(prdata), .pready(pready), .pslverr(pslverr)
    );

    task automatic axi_write(
        input logic [31:0] a,
        input logic [31:0] d,
        input logic [3:0] s
    );
        begin
            @(negedge clk);
            awaddr = a;
            awvalid = 1;
            do @(posedge clk); while (awready !== 1'b1);
            @(negedge clk);
            awvalid = 0;

            wdata = d;
            wstrb = s;
            wvalid = 1;
            do @(posedge clk); while (wready !== 1'b1);
            @(negedge clk);
            wvalid = 0;

            do @(posedge clk); while (bvalid !== 1'b1);
            if (bresp !== 2'b00)
                $fatal(1, "Random write BRESP error: %b", bresp);

            @(negedge clk);
            bready = 1;
            @(posedge clk);
            @(negedge clk);
            bready = 0;
        end
    endtask

    task automatic axi_read(
        input logic [31:0] a,
        output logic [31:0] d
    );
        begin
            @(negedge clk);
            araddr = a;
            arvalid = 1;
            do @(posedge clk); while (arready !== 1'b1);
            @(negedge clk);
            arvalid = 0;

            do @(posedge clk); while (rvalid !== 1'b1);
            d = rdata;

            if (rresp !== 2'b00)
                $fatal(1, "Random read RRESP error: %b", rresp);

            @(negedge clk);
            rready = 1;
            @(posedge clk);
            @(negedge clk);
            rready = 0;
        end
    endtask

    initial begin
        passed = 0;
        failed = 0;

        awaddr = 0; awvalid = 0;
        wdata = 0; wstrb = 0; wvalid = 0;
        bready = 0;
        araddr = 0; arvalid = 0; rready = 0;

        for (i = 0; i < 16; i = i + 1)
            expected_mem[i] = 0;

        repeat (3) @(negedge clk);
        resetn = 1;
        repeat (2) @(negedge clk);

        $display("=== Randomized AXI Write/Read Test ===");

        for (i = 0; i < 100; i = i + 1) begin
            // 16 aligned memory words, addresses 0x00 to 0x3C
            addr = ($urandom_range(0, 15) * 4);
            data = $urandom;
            strb = $urandom_range(1, 15);

            axi_write(addr, data, strb);

            // Update reference model only for selected byte lanes
            for (lane = 0; lane < 4; lane = lane + 1)
                if (strb[lane])
                    expected_mem[addr >> 2][lane*8 +: 8]
                        = data[lane*8 +: 8];

            axi_read(addr, actual);
            expected = expected_mem[addr >> 2];

            if (actual === expected) begin
                passed = passed + 1;
            end else begin
                failed = failed + 1;
                $display(
                    "FAIL iter=%0d addr=%h strb=%b expected=%h actual=%h",
                    i, addr, strb, expected, actual
                );
            end
        end

        $display("-----------------------------------");
        $display("Random transactions checked: %0d", 100);
        $display("Readback PASS: %0d", passed);
        $display("Readback FAIL: %0d", failed);
        $display("-----------------------------------");

        if (failed == 0)
            $display("RANDOMIZED AXI TEST PASSED");
        else
            $fatal(1, "RANDOMIZED AXI TEST FAILED");

        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "Random test timeout");
    end

endmodule
