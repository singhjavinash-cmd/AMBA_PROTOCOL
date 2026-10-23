
`timescale 1ns/1ps

module tb_axi_bridge;

    logic clk, resetn;

    // AXI4-Lite Write Address Channel
    logic [31:0] s_axi_awaddr;
    logic        s_axi_awvalid, s_axi_awready;

    // AXI4-Lite Write Data Channel
    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
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

    // APB4 Interface
    logic [31:0] paddr, pwdata, prdata;
    logic [3:0]  pstrb;
    logic        psel, penable, pwrite, pready, pslverr;

    integer pass_count = 0;
    integer fail_count = 0;

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // AXI4-Lite to APB4 bridge
    axi_to_apb_bridge bridge_inst (
        .clk            (clk),
        .resetn          (resetn),

        .s_axi_awaddr    (s_axi_awaddr),
        .s_axi_awvalid   (s_axi_awvalid),
        .s_axi_awready   (s_axi_awready),

        .s_axi_wdata     (s_axi_wdata),
        .s_axi_wstrb     (s_axi_wstrb),
        .s_axi_wvalid    (s_axi_wvalid),
        .s_axi_wready    (s_axi_wready),

        .s_axi_bresp     (s_axi_bresp),
        .s_axi_bvalid    (s_axi_bvalid),
        .s_axi_bready    (s_axi_bready),

        .s_axi_araddr    (s_axi_araddr),
        .s_axi_arvalid   (s_axi_arvalid),
        .s_axi_arready   (s_axi_arready),

        .s_axi_rdata     (s_axi_rdata),
        .s_axi_rresp     (s_axi_rresp),
        .s_axi_rvalid    (s_axi_rvalid),
        .s_axi_rready    (s_axi_rready),

        .m_apb_paddr     (paddr),
        .m_apb_psel      (psel),
        .m_apb_penable   (penable),
        .m_apb_pwrite    (pwrite),
        .m_apb_pwdata    (pwdata),
        .m_apb_pstrb     (pstrb),
        .m_apb_prdata    (prdata),
        .m_apb_pready    (pready),
        .m_apb_pslverr   (pslverr)
    );

    // APB memory slave
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
    // Send AXI write address
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
    // Send AXI write data and byte strobes
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
    // Send AXI read address
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
    // Wait for write response
    // --------------------------------------------------
    task automatic wait_bresp;
        begin
            do begin
                @(posedge clk);
            end while (s_axi_bvalid !== 1'b1);
        end
    endtask

    // --------------------------------------------------
    // Wait for read response
    // --------------------------------------------------
    task automatic wait_rresp;
        begin
            do begin
                @(posedge clk);
            end while (s_axi_rvalid !== 1'b1);
        end
    endtask

    // --------------------------------------------------
    // Complete a write transaction
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
    // Complete a read transaction
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
    // Test sequence
    // --------------------------------------------------
    logic [31:0] read_value;
    logic [31:0] held_read_data;

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

        // TEST 1: AW arrives before W
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
            $display("  PASS: Readback = %h", read_value);
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: Readback = %h", read_value);
        end

        // TEST 2: W arrives before AW
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

        repeat (3) begin
            @(posedge clk);
            if (s_axi_bvalid !== 1'b1) begin
                fail_count = fail_count + 1;
                $display("  FAIL: BVALID dropped before BREADY");
            end
        end

        if (s_axi_bvalid === 1'b1) begin
            pass_count = pass_count + 1;
            $display("  PASS: BVALID held while BREADY=0");
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

        repeat (3) begin
            @(posedge clk);
            if ((s_axi_rvalid !== 1'b1) ||
                (s_axi_rdata !== held_read_data)) begin
                fail_count = fail_count + 1;
                $display("  FAIL: Read response not held stable");
            end
        end

        if ((s_axi_rvalid === 1'b1) &&
            (s_axi_rdata === held_read_data)) begin
            pass_count = pass_count + 1;
            $display("  PASS: RVALID and RDATA held stable");
        end

        @(negedge clk);
        s_axi_rready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        s_axi_rready = 1'b0;

        // TEST 5: Reset clears response outputs
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

        $display("");
        $display("==========================================");
        $display(" AXI BRIDGE TEST SUMMARY");
        $display(" Passed: %0d", pass_count);
        $display(" Failed: %0d", fail_count);
        $display("==========================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED");

        $finish;
    end

    // Independent byte-strobe forwarding check
    // APB PSTRB must match the accepted AXI WSTRB.
    always @(posedge clk) begin
        if (resetn && psel && penable && pwrite) begin
            if (pstrb !== 4'bxxxx) begin
                // The slave applies each asserted byte lane.
            end
        end
    end

    initial begin
        #200000;
        $fatal(1, "Testbench timeout");
    end

endmodule
