
`timescale 1ns/1ps

module tb_axi_bridge;

    logic clk, resetn;

    // AXI4-Lite Write Address Channel
    logic [31:0] s_axi_awaddr;
    logic        s_axi_awvalid, s_axi_awready;

    // AXI4-Lite Write Data Channel
    logic [31:0] s_axi_wdata;
    logic        s_axi_wvalid, s_axi_wready;

    // AXI4-Lite Write Response Channel
    logic [1:0] s_axi_bresp;
    logic       s_axi_bvalid, s_axi_bready;

    // AXI4-Lite Read Address Channel
    logic [31:0] s_axi_araddr;
    logic        s_axi_arvalid, s_axi_arready;

    // AXI4-Lite Read Data Channel
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid, s_axi_rready;

    // APB Interface
    logic [31:0] paddr, pwdata, prdata;
    logic psel, penable, pwrite, pready, pslverr;

    // 100 MHz clock
    always #5 clk = ~clk;

    // DUT: AXI4-Lite to APB Bridge
    axi_to_apb_bridge bridge_inst (
        .clk(clk),
        .resetn(resetn),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .m_apb_paddr(paddr),
        .m_apb_psel(psel),
        .m_apb_penable(penable),
        .m_apb_pwrite(pwrite),
        .m_apb_pwdata(pwdata),
        .m_apb_prdata(prdata),
        .m_apb_pready(pready),
        .m_apb_pslverr(pslverr)
    );

    // APB Memory Slave
    apb_slave slave_inst (
        .pclk(clk),
        .presetn(resetn),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr)
    );

    // --------------------------------------------------
    // Task: Send AXI Write Address
    // --------------------------------------------------
    task automatic send_aw(input logic [31:0] addr);
        begin
            @(negedge clk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;

            do @(posedge clk);
            while (s_axi_awready !== 1'b1);

            @(negedge clk);
            s_axi_awvalid = 1'b0;
        end
    endtask

    // --------------------------------------------------
    // Task: Send AXI Write Data
    // --------------------------------------------------
    task automatic send_w(input logic [31:0] data);
        begin
            @(negedge clk);
            s_axi_wdata  = data;
            s_axi_wvalid = 1'b1;

            do @(posedge clk);
            while (s_axi_wready !== 1'b1);

            @(negedge clk);
            s_axi_wvalid = 1'b0;
        end
    endtask

    // --------------------------------------------------
    // Task: Check Write Response
    // --------------------------------------------------
    task automatic check_write_response(
        input logic [1:0] expected_resp
    );
        begin
            wait (s_axi_bvalid === 1'b1);

            if (s_axi_bresp !== expected_resp)
                $fatal(1,
                    "[FAIL] BRESP expected=%b actual=%b",
                    expected_resp, s_axi_bresp);

            $display("[PASS] BRESP=%b", s_axi_bresp);
        end
    endtask

    // --------------------------------------------------
    // Task: Read and Check Memory Word
    // --------------------------------------------------
    task automatic read_word(
        input logic [31:0] addr,
        input logic [31:0] expected_data
    );
        begin
            @(negedge clk);
            s_axi_araddr  = addr;
            s_axi_arvalid = 1'b1;

            do @(posedge clk);
            while (s_axi_arready !== 1'b1);

            @(negedge clk);
            s_axi_arvalid = 1'b0;

            wait (s_axi_rvalid === 1'b1);

            if (s_axi_rdata !== expected_data)
                $fatal(1,
                    "[FAIL] Read addr=%h expected=%h actual=%h",
                    addr, expected_data, s_axi_rdata);

            if (s_axi_rresp !== 2'b00)
                $fatal(1,
                    "[FAIL] Read response was not OKAY: %b",
                    s_axi_rresp);

            $display("[PASS] Read addr=%h data=%h",
                     addr, s_axi_rdata);

            // Complete the read response handshake.
            @(negedge clk);
            s_axi_rready = 1'b1;

            do @(posedge clk);
            while (s_axi_rvalid !== 1'b1);

            @(negedge clk);
            s_axi_rready = 1'b0;
        end
    endtask

    // --------------------------------------------------
    // Main Test Sequence
    // --------------------------------------------------
    initial begin
        $dumpfile("axi_bridge_waveform.vcd");
        $dumpvars(0, tb_axi_bridge);
        
        clk           = 1'b0;
        resetn        = 1'b0;

        s_axi_awaddr  = '0;
        s_axi_awvalid = 1'b0;

        s_axi_wdata   = '0;
        s_axi_wvalid  = 1'b0;

        s_axi_bready  = 1'b0;

        s_axi_araddr  = '0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        // Initial reset
        repeat (4) @(negedge clk);
        resetn = 1'b1;

        // ==============================================
        // TEST 1: AW arrives before W
        // ==============================================
        $display("\n[TEST 1] AW before W");

        send_aw(32'h0000_0004);
        send_w(32'hCAFE_BABE);

        check_write_response(2'b00);

        // Accept write response
        @(negedge clk);
        s_axi_bready = 1'b1;

        do @(posedge clk);
        while (s_axi_bvalid !== 1'b1);

        @(negedge clk);
        s_axi_bready = 1'b0;

        read_word(32'h0000_0004, 32'hCAFE_BABE);

        // ==============================================
        // TEST 2: W arrives before AW
        // ==============================================
        $display("\n[TEST 2] W before AW");

        send_w(32'h1234_ABCD);
        send_aw(32'h0000_0008);

        check_write_response(2'b00);

        @(negedge clk);
        s_axi_bready = 1'b1;

        do @(posedge clk);
        while (s_axi_bvalid !== 1'b1);

        @(negedge clk);
        s_axi_bready = 1'b0;

        read_word(32'h0000_0008, 32'h1234_ABCD);

        // ==============================================
        // TEST 3: BREADY backpressure
        // ==============================================
        $display("\n[TEST 3] Write response backpressure");

        // Keep BREADY low throughout the transaction.
        s_axi_bready = 1'b0;

        fork
            begin
                send_aw(32'h0000_000C);
                send_w(32'h5555_AAAA);
            end

            begin
                wait (s_axi_bvalid === 1'b1);

                repeat (3) begin
                    @(negedge clk);

                    if (s_axi_bvalid !== 1'b1 ||
                        s_axi_bresp  !== 2'b00)
                        $fatal(1,
                            "[FAIL] Write response changed while stalled");
                end

                $display(
                    "[PASS] BVALID/BRESP stable while BREADY=0");
            end
        join

        // Release write response
        @(negedge clk);
        s_axi_bready = 1'b1;

        do @(posedge clk);
        while (s_axi_bvalid !== 1'b1);

        @(negedge clk);
        s_axi_bready = 1'b0;

        read_word(32'h0000_000C, 32'h5555_AAAA);

        // ==============================================
        // TEST 4: RREADY backpressure
        // ==============================================
        $display("\n[TEST 4] Read response backpressure");

        @(negedge clk);
        s_axi_araddr  = 32'h0000_0004;
        s_axi_arvalid = 1'b1;

        do @(posedge clk);
        while (s_axi_arready !== 1'b1);

        @(negedge clk);
        s_axi_arvalid = 1'b0;

        // Stall the read response.
        s_axi_rready = 1'b0;

        wait (s_axi_rvalid === 1'b1);

        repeat (3) begin
            @(negedge clk);

            if (s_axi_rvalid !== 1'b1 ||
                s_axi_rdata  !== 32'hCAFE_BABE ||
                s_axi_rresp  !== 2'b00)
                $fatal(1,
                    "[FAIL] Read response changed while stalled");
        end

        $display(
            "[PASS] RVALID/RDATA/RRESP stable while RREADY=0");

        // Complete read handshake.
        @(negedge clk);
        s_axi_rready = 1'b1;

        do @(posedge clk);
        while (s_axi_rvalid !== 1'b1);

        @(negedge clk);
        s_axi_rready = 1'b0;

        // ==============================================
        // TEST 5: Reset clears response and APB control
        // ==============================================
        $display("\n[TEST 5] Reset verification");

        // Ensure no AXI response is outstanding.
        repeat (2) @(negedge clk);

        resetn = 1'b0;
        repeat (2) @(negedge clk);

        if (s_axi_bvalid !== 1'b0 ||
            s_axi_rvalid !== 1'b0)
            $fatal(1,
                "[FAIL] AXI valid signals not cleared by reset");

        if (psel !== 1'b0 || penable !== 1'b0)
            $fatal(1,
                "[FAIL] APB control not cleared by reset");

        $display(
            "[PASS] Reset clears AXI responses and APB control");

        @(negedge clk);
        resetn = 1'b1;

        repeat (2) @(negedge clk);

        $display("\nALL FIVE AXI4-LITE TESTS PASSED");
        $finish;
    end

    // Simulation timeout protection
    initial begin
        #100000;
        $fatal(1, "[FAIL] Simulation timeout");
    end

endmodule
