`timescale 1ns/1ps

module tb_apb_subsystem;

    logic clk = 0;
    logic resetn = 0;

    logic [31:0] awaddr, wdata, araddr;
    logic [3:0]  wstrb;
    logic awvalid, awready, wvalid, wready;
    logic bready, bvalid;
    logic [1:0] bresp;
    logic arvalid, arready, rready, rvalid;
    logic [31:0] rdata;
    logic [1:0] rresp;

    logic [31:0] dbg_paddr, dbg_pwdata, dbg_prdata;
    logic [3:0]  dbg_pstrb;
    logic dbg_psel, dbg_penable, dbg_pwrite;
    logic dbg_pready, dbg_pslverr;

    integer passed = 0;

    always #5 clk = ~clk;

    apb_subsystem dut (
        .clk(clk),
        .resetn(resetn),

        .s_axi_awaddr(awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),

        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),

        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),

        .s_axi_araddr(araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),

        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),

        .dbg_paddr(dbg_paddr),
        .dbg_psel(dbg_psel),
        .dbg_penable(dbg_penable),
        .dbg_pwrite(dbg_pwrite),
        .dbg_pwdata(dbg_pwdata),
        .dbg_pstrb(dbg_pstrb),
        .dbg_prdata(dbg_prdata),
        .dbg_pready(dbg_pready),
        .dbg_pslverr(dbg_pslverr)
    );

    // -----------------------------------------------------
    // AXI4-Lite WRITE TASK
    // -----------------------------------------------------
    task automatic axi_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0] strb,
        input logic [1:0] expected_resp
    );
        bit aw_done;
        bit w_done;
        integer timeout_count;

        begin
            aw_done = 0;
            w_done = 0;
            timeout_count = 0;

            @(negedge clk);
            awaddr  = addr;
            wdata   = data;
            wstrb   = strb;
            awvalid = 1;
            wvalid  = 1;
            bready  = 0;

            while (!(aw_done && w_done) && timeout_count < 100) begin
                @(posedge clk);

                if (awvalid && awready)
                    aw_done = 1;

                if (wvalid && wready)
                    w_done = 1;

                timeout_count = timeout_count + 1;

                @(negedge clk);

                if (aw_done)
                    awvalid = 0;

                if (w_done)
                    wvalid = 0;
            end

            if (!(aw_done && w_done))
                $fatal(1, "TIMEOUT: AXI write handshake addr=%h", addr);

            timeout_count = 0;

            while (bvalid !== 1'b1 && timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (bvalid !== 1'b1)
                $fatal(1, "TIMEOUT: AXI B response addr=%h", addr);

            if (bresp !== expected_resp)
                $fatal(1,
                    "WRITE FAIL addr=%h BRESP=%b expected=%b",
                    addr, bresp, expected_resp);

            $display("[PASS] WRITE addr=%h data=%h strb=%b resp=%b",
                     addr, data, strb, bresp);

            @(negedge clk);
            bready = 1;

            @(posedge clk);
            @(negedge clk);
            bready = 0;

            passed = passed + 1;
        end
    endtask

    // -----------------------------------------------------
    // AXI4-Lite READ TASK: compare expected data and response
    // -----------------------------------------------------
    task automatic axi_read(
        input logic [31:0] addr,
        input logic [31:0] expected,
        input logic [1:0] expected_resp
    );
        integer timeout_count;
        bit ar_done;

        begin
            timeout_count = 0;
            ar_done = 0;

            @(negedge clk);
            araddr  = addr;
            arvalid = 1;
            rready  = 0;

            while (!ar_done && timeout_count < 100) begin
                @(posedge clk);

                if (arvalid && arready)
                    ar_done = 1;

                timeout_count = timeout_count + 1;
            end

            if (!ar_done)
                $fatal(1, "TIMEOUT: AR handshake addr=%h", addr);

            @(negedge clk);
            arvalid = 0;

            timeout_count = 0;

            while (rvalid !== 1'b1 && timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (rvalid !== 1'b1)
                $fatal(1, "TIMEOUT: R response addr=%h", addr);

            if (rresp !== expected_resp)
                $fatal(1,
                    "READ FAIL addr=%h RRESP=%b expected=%b",
                    addr, rresp, expected_resp);

            if (expected_resp == 2'b00 && rdata !== expected)
                $fatal(1,
                    "READ FAIL addr=%h data=%h expected=%h",
                    addr, rdata, expected);

            $display("[PASS] READ addr=%h data=%h resp=%b",
                     addr, rdata, rresp);

            @(negedge clk);
            rready = 1;

            @(posedge clk);
            @(negedge clk);
            rready = 0;

            passed = passed + 1;
        end
    endtask

    // -----------------------------------------------------
    // TIMER COUNTER READ TASK
    // Checks response and captures the live counter value.
    // -----------------------------------------------------
    task automatic axi_read_timer_counter(
        output logic [31:0] counter_value
    );
        integer timeout_count;
        bit ar_done;

        begin
            timeout_count = 0;
            ar_done = 0;
            counter_value = 0;

            @(negedge clk);
            araddr  = 32'h0000_1004;
            arvalid = 1;
            rready  = 0;

            while (!ar_done && timeout_count < 100) begin
                @(posedge clk);

                if (arvalid && arready)
                    ar_done = 1;

                timeout_count = timeout_count + 1;
            end

            if (!ar_done)
                $fatal(1, "TIMEOUT: Timer counter AR handshake");

            @(negedge clk);
            arvalid = 0;

            timeout_count = 0;

            while (rvalid !== 1'b1 && timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (rvalid !== 1'b1)
                $fatal(1, "TIMEOUT: Timer counter R response");

            if (rresp !== 2'b00)
                $fatal(1, "Timer counter read failed: RRESP=%b", rresp);

            counter_value = rdata;

            $display("[PASS] TIMER COUNTER READ value=%0d (0x%08h)",
                     counter_value, counter_value);

            @(negedge clk);
            rready = 1;

            @(posedge clk);
            @(negedge clk);
            rready = 0;

            passed = passed + 1;
        end
    endtask

    // -----------------------------------------------------
    // MAIN TEST SEQUENCE
    // -----------------------------------------------------
    initial begin : test_sequence
        logic [31:0] counter_before;
        logic [31:0] counter_after;

        awaddr  = 0;
        wdata   = 0;
        wstrb   = 0;
        awvalid = 0;
        wvalid  = 0;
        bready  = 0;

        araddr  = 0;
        arvalid = 0;
        rready  = 0;

        repeat (4) @(negedge clk);
        resetn = 1;
        repeat (2) @(negedge clk);

        $display("\n======================================");
        $display(" AXI4-Lite to APB Subsystem Test");
        $display("======================================");

        // Test 1: Full-word memory write/read.
        axi_write(32'h0000_0004, 32'h1122_3344,
                  4'b1111, 2'b00);

        axi_read(32'h0000_0004, 32'h1122_3344, 2'b00);

        // Test 2: Partial-byte write to lane 0.
        axi_write(32'h0000_0004, 32'h0000_00AA,
                  4'b0001, 2'b00);

        axi_read(32'h0000_0004, 32'h1122_33AA, 2'b00);

        // Test 3: Timer initially disabled.
        axi_write(32'h0000_1000, 32'h0000_0000,
                  4'b0001, 2'b00);

        axi_read(32'h0000_1000, 32'h0000_0000, 2'b00);
        axi_read(32'h0000_1004, 32'h0000_0000, 2'b00);

        // Test 4: Enable timer and capture a live counter value.
        axi_write(32'h0000_1000, 32'h0000_0001,
                  4'b0001, 2'b00);

        axi_read_timer_counter(counter_before);

        // Allow the timer to advance.
        repeat (10) @(negedge clk);

        axi_read_timer_counter(counter_after);

        if (counter_after > counter_before) begin
            $display("[PASS] TIMER INCREMENT before=%0d after=%0d",
                     counter_before, counter_after);
            passed = passed + 1;
        end else begin
            $fatal(1,
                "TIMER DID NOT INCREMENT: before=%0d after=%0d",
                counter_before, counter_after);
        end

        // Test 5: Unmapped read must return SLVERR.
        axi_read(32'h0000_2000, 32'h0000_0000, 2'b10);

        $display("\n======================================");
        $display("TOTAL CHECKS PASSED: %0d", passed);
        $display("SUBSYSTEM TEST COMPLETED");
        $display("======================================");

        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "GLOBAL TEST TIMEOUT");
    end

endmodule