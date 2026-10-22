`timescale 1ns/1ps

module tb_multislave_subsystem;

    logic        clk;
    logic        resetn;

    // AXI4-Lite Write Address Channel
    logic [31:0] s_axi_awaddr;
    logic        s_axi_awvalid;
    logic        s_axi_awready;

    // AXI4-Lite Write Data Channel
    logic [31:0] s_axi_wdata;
    logic        s_axi_wvalid;
    logic        s_axi_wready;

    // AXI4-Lite Write Response Channel
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic        s_axi_bready;

    // AXI4-Lite Read Address Channel
    logic [31:0] s_axi_araddr;
    logic        s_axi_arvalid;
    logic        s_axi_arready;

    // AXI4-Lite Read Data Channel
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid;
    logic        s_axi_rready;

    // APB master signals
    logic [31:0] m_paddr;
    logic        m_psel;
    logic        m_penable;
    logic        m_pwrite;
    logic [31:0] m_pwdata;
    logic [31:0] m_prdata;
    logic        m_pready;
    logic        m_pslverr;

    // Peripheral selection and response signals
    logic        psel_mem;
    logic        psel_timer;
    logic        psel_unmapped;

    logic [31:0] prdata_mem;
    logic [31:0] prdata_timer;

    logic        pready_mem;
    logic        pready_timer;

    integer tests_passed;

    // 100 MHz clock: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =====================================================
    // DUT: AXI4-Lite to APB Bridge
    // =====================================================

    axi_to_apb_bridge bridge_inst (
        .clk           (clk),
        .resetn        (resetn),

        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),

        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),

        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),

        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),

        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),

        .m_apb_paddr   (m_paddr),
        .m_apb_psel    (m_psel),
        .m_apb_penable (m_penable),
        .m_apb_pwrite  (m_pwrite),
        .m_apb_pwdata  (m_pwdata),
        .m_apb_prdata  (m_prdata),
        .m_apb_pready  (m_pready),
        .m_apb_pslverr (m_pslverr)
    );

    // =====================================================
    // Address Decoder and APB Response Multiplexer
    // =====================================================

    // 0x0000-0x0FFF: Memory
    // 0x1000-0x1FFF: Timer
    // 0x2000 and above: Unmapped address

    assign psel_mem =
        m_psel && (m_paddr[15:12] == 4'h0);

    assign psel_timer =
        m_psel && (m_paddr[15:12] == 4'h1);

    assign psel_unmapped =
        m_psel && (m_paddr[15:12] >= 4'h2);

    always_comb begin
        m_prdata  = 32'h0;
        m_pready  = 1'b1;
        m_pslverr = 1'b0;

        if (psel_mem) begin
            m_prdata  = prdata_mem;
            m_pready  = pready_mem;
            m_pslverr = 1'b0;
        end
        else if (psel_timer) begin
            m_prdata  = prdata_timer;
            m_pready  = pready_timer;
            m_pslverr = 1'b0;
        end
        else if (psel_unmapped) begin
            m_prdata  = 32'hDEAD_DEAD;
            m_pready  = m_penable;
            m_pslverr = 1'b1;
        end
    end

    // =====================================================
    // APB Memory Slave
    // =====================================================

    apb_slave slave_mem (
        .pclk    (clk),
        .presetn (resetn),
        .paddr   (m_paddr),
        .psel    (psel_mem),
        .penable (m_penable),
        .pwrite  (m_pwrite),
        .pwdata  (m_pwdata),
        .prdata  (prdata_mem),
        .pready  (pready_mem),
        .pslverr ()
    );

    // =====================================================
    // APB Timer Peripheral
    // =====================================================

    apb_timer slave_timer (
        .pclk    (clk),
        .presetn (resetn),
        .paddr   (m_paddr),
        .psel    (psel_timer),
        .penable (m_penable),
        .pwrite  (m_pwrite),
        .pwdata  (m_pwdata),
        .prdata  (prdata_timer),
        .pready  (pready_timer),
        .pslverr ()
    );

    // =====================================================
    // APB Protocol Checkers
    // =====================================================

    apb_sva sva_mem (
        .pclk    (clk),
        .presetn (resetn),
        .psel    (psel_mem),
        .penable (m_penable),
        .pwrite  (m_pwrite),
        .paddr   (m_paddr),
        .pwdata  (m_pwdata),
        .pready  (pready_mem)
    );

    apb_sva sva_timer (
        .pclk    (clk),
        .presetn (resetn),
        .psel    (psel_timer),
        .penable (m_penable),
        .pwrite  (m_pwrite),
        .paddr   (m_paddr),
        .pwdata  (m_pwdata),
        .pready  (pready_timer)
    );

    // =====================================================
    // Test Stimulus
    // =====================================================

    initial begin
        $dumpfile("multislave.vcd");
        $dumpvars(0, tb_multislave_subsystem);

        tests_passed = 0;

        resetn        = 1'b0;

        s_axi_awaddr  = 32'h0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = 32'h0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;

        s_axi_araddr  = 32'h0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        repeat (4) @(negedge clk);
        resetn = 1'b1;
        repeat (2) @(negedge clk);

        // -------------------------------------------------
        // TEST 1: Write memory address 0x0004
        // -------------------------------------------------

        $display("\n[TEST 1] Memory write");

        fork
            begin
                @(negedge clk);
                s_axi_awaddr  = 32'h0000_0004;
                s_axi_awvalid = 1'b1;

                do @(posedge clk);
                while (!s_axi_awready);

                @(negedge clk);
                s_axi_awvalid = 1'b0;
            end

            begin
                repeat (2) @(negedge clk);
                s_axi_wdata  = 32'hAAAA_BBBB;
                s_axi_wvalid = 1'b1;

                do @(posedge clk);
                while (!s_axi_wready);

                @(negedge clk);
                s_axi_wvalid = 1'b0;
            end
        join

        wait (s_axi_bvalid === 1'b1);

        if (s_axi_bresp === 2'b00) begin
            $display("[PASS] Memory write BRESP=OKAY");
            tests_passed = tests_passed + 1;
        end
        else begin
            $fatal(1, "[FAIL] Memory write BRESP=%b", s_axi_bresp);
        end

        @(negedge clk);
        s_axi_bready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        s_axi_bready = 1'b0;

        // -------------------------------------------------
        // TEST 2: Enable timer at address 0x1000
        // -------------------------------------------------

        $display("\n[TEST 2] Timer enable write");

        @(negedge clk);
        s_axi_awaddr  = 32'h0000_1000;
        s_axi_awvalid = 1'b1;
        s_axi_wdata   = 32'h0000_0001;
        s_axi_wvalid  = 1'b1;

        do @(posedge clk);
        while (!(s_axi_awready && s_axi_wready));

        @(negedge clk);
        s_axi_awvalid = 1'b0;
        s_axi_wvalid  = 1'b0;

        wait (s_axi_bvalid === 1'b1);

        if (s_axi_bresp === 2'b00) begin
            $display("[PASS] Timer enable BRESP=OKAY");
            tests_passed = tests_passed + 1;
        end
        else begin
            $fatal(1, "[FAIL] Timer enable BRESP=%b", s_axi_bresp);
        end

        @(negedge clk);
        s_axi_bready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        s_axi_bready = 1'b0;

        repeat (10) @(negedge clk);

        // -------------------------------------------------
        // TEST 3: Read memory address 0x0004
        // -------------------------------------------------

        $display("\n[TEST 3] Memory read");

        @(negedge clk);
        s_axi_araddr  = 32'h0000_0004;
        s_axi_arvalid = 1'b1;

        do @(posedge clk);
        while (!s_axi_arready);

        @(negedge clk);
        s_axi_arvalid = 1'b0;

        s_axi_rready = 1'b1;
        wait (s_axi_rvalid === 1'b1);

        if ((s_axi_rdata === 32'hAAAA_BBBB) &&
            (s_axi_rresp === 2'b00)) begin
            $display("[PASS MEMORY] Addr=0x0004 Data=0x%08h",
                     s_axi_rdata);
            tests_passed = tests_passed + 1;
        end
        else begin
            $fatal(1, "[FAIL MEMORY] Data=%h RRESP=%b",
                   s_axi_rdata, s_axi_rresp);
        end

        @(posedge clk);
        @(negedge clk);
        s_axi_rready = 1'b0;

        // -------------------------------------------------
        // TEST 4: Read timer counter at address 0x1004
        // -------------------------------------------------

        $display("\n[TEST 4] Timer counter read");

        @(negedge clk);
        s_axi_araddr  = 32'h0000_1004;
        s_axi_arvalid = 1'b1;

        do @(posedge clk);
        while (!s_axi_arready);

        @(negedge clk);
        s_axi_arvalid = 1'b0;

        s_axi_rready = 1'b1;
        wait (s_axi_rvalid === 1'b1);

        if (s_axi_rresp === 2'b00) begin
            $display("[PASS TIMER] Addr=0x1004 Counter=%0d",
                     s_axi_rdata);
            tests_passed = tests_passed + 1;
        end
        else begin
            $fatal(1, "[FAIL TIMER] RRESP=%b", s_axi_rresp);
        end

        @(posedge clk);
        @(negedge clk);
        s_axi_rready = 1'b0;

        // -------------------------------------------------
        // TEST 5: Unmapped write at address 0x3000
        // -------------------------------------------------

        $display("\n[TEST 5] Unmapped write");

        @(negedge clk);
        s_axi_awaddr  = 32'h0000_3000;
        s_axi_awvalid = 1'b1;
        s_axi_wdata   = 32'hDEAD_BEEF;
        s_axi_wvalid  = 1'b1;

        do @(posedge clk);
        while (!(s_axi_awready && s_axi_wready));

        @(negedge clk);
        s_axi_awvalid = 1'b0;
        s_axi_wvalid  = 1'b0;

        s_axi_bready = 1'b1;
        wait (s_axi_bvalid === 1'b1);

        if (s_axi_bresp === 2'b10) begin
            $display("[PASS] Unmapped write BRESP=SLVERR");
            tests_passed = tests_passed + 1;
        end
        else begin
            $fatal(1, "[FAIL] Unmapped write BRESP=%b", s_axi_bresp);
        end

        @(posedge clk);
        @(negedge clk);
        s_axi_bready = 1'b0;

        // -------------------------------------------------
        // TEST 6: Unmapped read at address 0x3000
        // -------------------------------------------------

        $display("\n[TEST 6] Unmapped read");

        @(negedge clk);
        s_axi_araddr  = 32'h0000_3000;
        s_axi_arvalid = 1'b1;

        do @(posedge clk);
        while (!s_axi_arready);

        @(negedge clk);
        s_axi_arvalid = 1'b0;

        s_axi_rready = 1'b1;
        wait (s_axi_rvalid === 1'b1);

        if (s_axi_rresp === 2'b10) begin
            $display("[PASS] Unmapped read RRESP=SLVERR");
            tests_passed = tests_passed + 1;
        end
        else begin
            $fatal(1, "[FAIL] Unmapped read RRESP=%b",
                   s_axi_rresp);
        end

        @(posedge clk);
        @(negedge clk);
        s_axi_rready = 1'b0;

        // -------------------------------------------------
        // Final summary
        // -------------------------------------------------

        $display("\n======================================");
        $display("MULTI-SLAVE TESTS PASSED: %0d / 6", tests_passed);
        $display("======================================");

        $finish;
    end

    // Prevent a hung simulation.
    initial begin
        #100000;
        $fatal(1, "TIMEOUT: Multi-slave testbench did not finish");
    end

endmodule