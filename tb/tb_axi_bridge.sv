`timescale 1ns/1ps

module tb_axi_bridge;

    logic clk, resetn;

    // AXI4-Lite write address channel
    logic [31:0] s_axi_awaddr;
    logic        s_axi_awvalid, s_axi_awready;

    // AXI4-Lite write data channel
    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wvalid, s_axi_wready;

    // AXI4-Lite write response channel
    logic [1:0] s_axi_bresp;
    logic       s_axi_bvalid, s_axi_bready;

    // AXI4-Lite read address channel
    logic [31:0] s_axi_araddr;
    logic        s_axi_arvalid, s_axi_arready;

    // AXI4-Lite read data channel
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid, s_axi_rready;

    // APB4 interface
    logic [31:0] paddr, pwdata, prdata;
    logic [3:0]  pstrb;
    logic        psel, penable, pwrite, pready, pslverr;

    integer pass_count = 0;
    integer fail_count = 0;

    logic [31:0] read_value;
    logic [31:0] held_read_data;
    logic [1:0]  held_bresp;
    logic [1:0]  held_rresp;

    // APB wait-state stability monitor
    integer apb_wait_cycles = 0;
    integer apb_wait_errors = 0;

    logic        apb_wait_active = 1'b0;
    logic [31:0] held_paddr;
    logic [31:0] held_pwdata;
    logic        held_pwrite;
    logic [3:0]  held_pstrb;

    // Clock generation
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // --------------------------------------------------
    // DUT: AXI4-Lite to APB4 Bridge
    // --------------------------------------------------
    axi_to_apb_bridge bridge_inst (
        .clk             (clk),
        .resetn           (resetn),

        .s_axi_awaddr     (s_axi_awaddr),
        .s_axi_awvalid    (s_axi_awvalid),
        .s_axi_awready    (s_axi_awready),

        .s_axi_wdata      (s_axi_wdata),
        .s_axi_wstrb      (s_axi_wstrb),
        .s_axi_wvalid     (s_axi_wvalid),
        .s_axi_wready     (s_axi_wready),

        .s_axi_bresp      (s_axi_bresp),
        .s_axi_bvalid     (s_axi_bvalid),
        .s_axi_bready     (s_axi_bready),

        .s_axi_araddr     (s_axi_araddr),
        .s_axi_arvalid    (s_axi_arvalid),
        .s_axi_arready    (s_axi_arready),

        .s_axi_rdata      (s_axi_rdata),
        .s_axi_rresp      (s_axi_rresp),
        .s_axi_rvalid     (s_axi_rvalid),
        .s_axi_rready     (s_axi_rready),

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

    // --------------------------------------------------
    // APB memory slave
    // --------------------------------------------------
    apb_slave slave_inst (
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

    // --------------------------------------------------
    // APB wait-state stability monitor
    // --------------------------------------------------
    always @(posedge clk) begin
        if (!resetn) begin
            apb_wait_active <= 1'b0;
            apb_wait_cycles <= 0;
            apb_wait_errors <= 0;
        end else begin

            if (apb_wait_active) begin
                if ((paddr !== held_paddr) ||
                    (pwrite !== held_pwrite) ||
                    (psel !== 1'b1) ||
                    (penable !== 1'b1) ||
                    (pwrite &&
                     ((pwdata !== held_pwdata) ||
                      (pstrb  !== held_pstrb)))) begin

                    apb_wait_errors <= apb_wait_errors + 1;

                    $error(
                        "APB signals changed during a stalled transfer"
                    );
                end
            end

            if (psel && penable && !pready) begin
                apb_wait_cycles <= apb_wait_cycles + 1;

                if (!apb_wait_active) begin
                    held_paddr  <= paddr;
                    held_pwdata <= pwdata;
                    held_pwrite <= pwrite;
                    held_pstrb  <= pstrb;
                end

                apb_wait_active <= 1'b1;
            end else begin
                apb_wait_active <= 1'b0;
            end
        end
    end

    // --------------------------------------------------
    // AXI write address task
    // --------------------------------------------------
    task automatic send_aw(input logic [31:0] addr);
        begin
            @(negedge clk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;

            do begin
                @(posedge clk);
            end while (s_axi_awready !== 1'b1);

            @(negedge clk);
            s_axi_awvalid = 1'b0;
        end
    endtask

    // --------------------------------------------------
    // AXI write data task
    // --------------------------------------------------
    task automatic send_w(
        input logic [31:0] data,
        input logic [3:0]  strb
    );
        begin
            @(negedge clk);
            s_axi_wdata  = data;
            s_axi_wstrb  = strb;
            s_axi_wvalid = 1'b1;

            do begin
                @(posedge clk);
            end while (s_axi_wready !== 1'b1);

            @(negedge clk);
            s_axi_wvalid = 1'b0;
        end
    endtask

    // --------------------------------------------------
    // AXI read address task
    // --------------------------------------------------
    task automatic send_ar(input logic [31:0] addr);
        begin
            @(negedge clk);
            s_axi_araddr  = addr;
            s_axi_arvalid = 1'b1;

            do begin
                @(posedge clk);
            end while (s_axi_arready !== 1'b1);

            @(negedge clk);
            s_axi_arvalid = 1'b0;
        end
    endtask

    // --------------------------------------------------
    // Wait for AXI write response
    // --------------------------------------------------
    task automatic wait_bresp;
        begin
            do begin
                @(posedge clk);
            end while (s_axi_bvalid !== 1'b1);
        end
    endtask

    // --------------------------------------------------
    // Wait for AXI read response
    // --------------------------------------------------
    task automatic wait_rresp;
        begin
            do begin
                @(posedge clk);
            end while (s_axi_rvalid !== 1'b1);
        end
    endtask

    // --------------------------------------------------
    // Complete one write transaction
    // --------------------------------------------------
    task automatic write_transaction(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0]  strb
    );
        begin
            send_aw(addr);
            send_w(data, strb);
            wait_bresp();

            @(negedge clk);
            s_axi_bready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            s_axi_bready = 1'b0;
        end
    endtask

    // --------------------------------------------------
    // Complete one read transaction
    // --------------------------------------------------
    task automatic read_transaction(
        input  logic [31:0] addr,
        output logic [31:0] data
    );
        begin
            send_ar(addr);
            wait_rresp();

            data = s_axi_rdata;

            @(negedge clk);
            s_axi_rready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            s_axi_rready = 1'b0;
        end
    endtask

    // --------------------------------------------------
    // Main test sequence
    // --------------------------------------------------
    initial begin
        $dumpfile("axi_bridge_waveform.vcd");
        $dumpvars(0, tb_axi_bridge);

        resetn         = 1'b0;
        s_axi_awaddr   = '0;
        s_axi_awvalid  = 1'b0;
        s_axi_wdata    = '0;
        s_axi_wstrb    = 4'b1111;
        s_axi_wvalid   = 1'b0;
        s_axi_bready   = 1'b0;
        s_axi_araddr   = '0;
        s_axi_arvalid  = 1'b0;
        s_axi_rready   = 1'b0;

        repeat (3) @(negedge clk);
        resetn = 1'b1;
        repeat (2) @(negedge clk);

        $display("");
        $display("==========================================");
        $display(" AXI4-Lite to APB4 Bridge Testbench");
        $display("==========================================");

        // TEST 1: AW before W
        $display("[TEST 1] Write address before write data");

        send_aw(32'h0000_0004);
        send_w(32'h1234_5678, 4'b1111);
        wait_bresp();

        if (s_axi_bresp == 2'b00) begin
            pass_count = pass_count + 1;
            $display("  PASS: Write response OKAY");
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: BRESP=%b", s_axi_bresp);
        end

        @(negedge clk);
        s_axi_bready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        s_axi_bready = 1'b0;

        read_transaction(32'h0000_0004, read_value);

        if (read_value == 32'h1234_5678) begin
            pass_count = pass_count + 1;
            $display("  PASS: Readback = %h", read_value);
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: Readback = %h", read_value);
        end

        // TEST 2: W before AW
        $display("[TEST 2] Write data before write address");

        send_w(32'hA5A5_5A5A, 4'b1111);
        send_aw(32'h0000_0008);
        wait_bresp();

        if (s_axi_bresp == 2'b00) begin
            pass_count = pass_count + 1;
            $display("  PASS: Write response OKAY");
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: BRESP=%b", s_axi_bresp);
        end

        @(negedge clk);
        s_axi_bready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        s_axi_bready = 1'b0;

        read_transaction(32'h0000_0008, read_value);

        if (read_value == 32'hA5A5_5A5A) begin
            pass_count = pass_count + 1;
            $display("  PASS: Readback = %h", read_value);
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: Readback = %h", read_value);
        end

        // TEST 3: BREADY backpressure
        $display("[TEST 3] Write response backpressure");

        send_aw(32'h0000_000C);
        send_w(32'hDEAD_BEEF, 4'b1111);
        wait_bresp();

        begin : test_bready
            integer errors;
            errors = 0;
            held_bresp = s_axi_bresp;

            repeat (3) begin
                @(negedge clk);

                if ((s_axi_bvalid !== 1'b1) ||
                    (s_axi_bresp !== held_bresp))
                    errors = errors + 1;
            end

            if (errors == 0) begin
                pass_count = pass_count + 1;
                $display("  PASS: BVALID and BRESP held stable");
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL: B response changed during backpressure");
            end
        end

        @(negedge clk);
        s_axi_bready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        s_axi_bready = 1'b0;

        // TEST 4: RREADY backpressure
        $display("[TEST 4] Read response backpressure");

        send_ar(32'h0000_0004);
        wait_rresp();

        held_read_data = s_axi_rdata;
        held_rresp     = s_axi_rresp;

        begin : test_rready
            integer errors;
            errors = 0;

            repeat (3) begin
                @(negedge clk);

                if ((s_axi_rvalid !== 1'b1) ||
                    (s_axi_rdata !== held_read_data) ||
                    (s_axi_rresp !== held_rresp))
                    errors = errors + 1;
            end

            if (errors == 0) begin
                pass_count = pass_count + 1;
                $display("  PASS: RVALID, RDATA and RRESP held stable");
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL: Read response changed during backpressure");
            end
        end

        @(negedge clk);
        s_axi_rready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        s_axi_rready = 1'b0;

        // TEST 5: Reset behavior
        $display("[TEST 5] Reset behavior");

        @(negedge clk);
        resetn = 1'b0;

        repeat (2) @(negedge clk);

        if ((s_axi_bvalid === 1'b0) &&
            (s_axi_rvalid === 1'b0) &&
            (psel === 1'b0) &&
            (penable === 1'b0)) begin

            pass_count = pass_count + 1;
            $display("  PASS: Reset clears response and APB controls");
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: Unexpected active outputs during reset");
        end

        resetn = 1'b1;
        repeat (2) @(negedge clk);

        // TEST 6: Partial-byte writes
        $display("[TEST 6] Partial-byte write verification");

        // Initialize word to 0x11223344
        write_transaction(
            32'h0000_0004,
            32'h1122_3344,
            4'b1111
        );

        // Update byte lane 0: 0x44 -> 0xAA
        write_transaction(
            32'h0000_0004,
            32'h1122_33AA,
            4'b0001
        );

        // Update byte lane 1: 0x33 -> 0xBB
        write_transaction(
            32'h0000_0004,
            32'h1122_BBAA,
            4'b0010
        );

        read_transaction(32'h0000_0004, read_value);

        if (read_value == 32'h1122_BBAA) begin
            pass_count = pass_count + 1;
            $display(
                "  PASS: Partial writes preserved untouched bytes: %h",
                read_value
            );
        end else begin
            fail_count = fail_count + 1;
            $display(
                "  FAIL: Expected 1122BBAA, got %h",
                read_value
            );
        end

        // TEST 7: APB wait-state stability
        $display("[TEST 7] APB wait-state stability");

        if ((apb_wait_errors == 0) && (apb_wait_cycles > 0)) begin
            pass_count = pass_count + 1;
            $display(
                "  PASS: APB stability checked across %0d stalled cycles",
                apb_wait_cycles
            );
        end else if (apb_wait_errors != 0) begin
            fail_count = fail_count + 1;
            $display(
                "  FAIL: APB monitor found %0d error(s)",
                apb_wait_errors
            );
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: No APB wait-state cycles observed");
        end

        // TEST 8: Invalid APB address - AXI write error
        $display("[TEST 8] Invalid address write error");

        send_aw(32'h0000_0040);
        send_w(32'hDEAD_BEEF, 4'b1111);
        wait_bresp();

        if (s_axi_bresp == 2'b10) begin
            pass_count = pass_count + 1;
            $display("  PASS: BRESP = SLVERR");
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: Expected BRESP=10, got %b", s_axi_bresp);
        end

        @(negedge clk);
        s_axi_bready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        s_axi_bready = 1'b0;

        // TEST 9: Invalid APB address - AXI read error
        $display("[TEST 9] Invalid address read error");

        send_ar(32'h0000_0040);
        wait_rresp();

        if ((s_axi_rresp == 2'b10) && (s_axi_rdata == 32'b0)) begin
            pass_count = pass_count + 1;
            $display("  PASS: RRESP=SLVERR, RDATA=0");
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: RRESP=%b RDATA=%h", s_axi_rresp, s_axi_rdata);
        end

        @(negedge clk);
        s_axi_rready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        s_axi_rready = 1'b0;

        // Final summary
        $display("");
        $display("==========================================");
        $display(" AXI BRIDGE TEST SUMMARY");
        $display(" Passed: %0d", pass_count);
        $display(" Failed: %0d", fail_count);
        $display("==========================================");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("TESTS FAILED");
            $fatal(1, "AXI bridge testbench failed: %0d failure(s)", fail_count);
        end

        $finish;
    end

    // Simulation timeout watchdog
    initial begin
        #200000;
        $fatal(1, "Testbench timeout");
    end

    // --------------------------------------------------
    // AXI4-Lite VALID/READY stability monitors
    // Procedural checks compatible with Icarus Verilog
    // --------------------------------------------------

    logic aw_was_stalled;
    logic w_was_stalled;
    logic b_was_stalled;
    logic r_was_stalled;

    logic [31:0] held_awaddr_monitor;
    logic [35:0] held_wpayload_monitor;
    logic [1:0]  held_bresp_monitor;
    logic [33:0] held_rpayload_monitor;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            aw_was_stalled       <= 1'b0;
            w_was_stalled        <= 1'b0;
            b_was_stalled        <= 1'b0;
            r_was_stalled        <= 1'b0;
            held_awaddr_monitor  <= '0;
            held_wpayload_monitor <= '0;
            held_bresp_monitor   <= '0;
            held_rpayload_monitor <= '0;
        end else begin
            // AW: address must remain stable until handshake.
            if (aw_was_stalled &&
                (!s_axi_awvalid || s_axi_awaddr !== held_awaddr_monitor))
                $error("AXI AW address/VALID changed while stalled");

            aw_was_stalled <= s_axi_awvalid && !s_axi_awready;
            if (s_axi_awvalid && !s_axi_awready)
                held_awaddr_monitor <= s_axi_awaddr;

            // W: data and strobes must remain stable until handshake.
            if (w_was_stalled &&
                (!s_axi_wvalid ||
                 {s_axi_wdata, s_axi_wstrb} !== held_wpayload_monitor))
                $error("AXI W data/strobes/VALID changed while stalled");

            w_was_stalled <= s_axi_wvalid && !s_axi_wready;
            if (s_axi_wvalid && !s_axi_wready)
                held_wpayload_monitor <= {s_axi_wdata, s_axi_wstrb};

            // B: response must remain stable while BREADY is low.
            if (b_was_stalled &&
                (!s_axi_bvalid || s_axi_bresp !== held_bresp_monitor))
                $error("AXI B response/VALID changed while stalled");

            b_was_stalled <= s_axi_bvalid && !s_axi_bready;
            if (s_axi_bvalid && !s_axi_bready)
                held_bresp_monitor <= s_axi_bresp;

            // R: data and response must remain stable while RREADY is low.
            if (r_was_stalled &&
                (!s_axi_rvalid ||
                 {s_axi_rdata, s_axi_rresp} !== held_rpayload_monitor))
                $error("AXI R data/response/VALID changed while stalled");

            r_was_stalled <= s_axi_rvalid && !s_axi_rready;
            if (s_axi_rvalid && !s_axi_rready)
                held_rpayload_monitor <= {s_axi_rdata, s_axi_rresp};
        end
    end

endmodule
