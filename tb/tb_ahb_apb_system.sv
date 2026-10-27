`timescale 1ns/1ps

module tb_ahb_apb_system;

    logic HCLK, HRESETn;

    // AHB master command interface
    logic start, write;
    logic [31:0] addr, wdata;
    logic [2:0] size;
    logic [31:0] rdata;
    logic busy, done, error;

    // AHB-Lite bus
    logic [31:0] HADDR, HWDATA, HRDATA;
    logic [1:0]  HTRANS;
    logic HWRITE, HSEL, HREADY;
    logic [2:0]  HSIZE;
    logic HREADYOUT, HRESP;

    // APB bridge-side signals
    logic PSEL, PENABLE, PWRITE;
    logic [31:0] PADDR, PWDATA, PRDATA;
    logic [3:0] PSTRB;
    logic PREADY, PSLVERR;

    // Individual APB slave selects
    logic PSEL_MEM, PSEL_TIMER;

    // Individual slave response signals
    logic [31:0] PRDATA_MEM, PRDATA_TIMER;
    logic PREADY_MEM, PREADY_TIMER;
    logic PSLVERR_MEM, PSLVERR_TIMER;

    integer errors = 0;
    integer checks = 0;

    // Wait-state stability monitor
    logic stalled_prev;
    logic [31:0] saved_paddr, saved_pwdata;
    logic [3:0] saved_pstrb;
    logic saved_pwrite;

    // --------------------------------------------------
    // Clock
    // --------------------------------------------------
    initial HCLK = 1'b0;
    always #5 HCLK = ~HCLK;

    // --------------------------------------------------
    // AHB-Lite master
    // --------------------------------------------------
    ahb_lite_master master (
        .HCLK     (HCLK),
        .HRESETn  (HRESETn),
        .start    (start),
        .write    (write),
        .addr     (addr),
        .wdata    (wdata),
        .size     (size),
        .rdata    (rdata),
        .busy     (busy),
        .done     (done),
        .error    (error),
        .HADDR    (HADDR),
        .HTRANS   (HTRANS),
        .HWRITE   (HWRITE),
        .HSIZE    (HSIZE),
        .HSEL     (HSEL),
        .HWDATA   (HWDATA),
        .HRDATA   (HRDATA),
        .HREADY   (HREADY),
        .HRESP    (HRESP)
    );

    // --------------------------------------------------
    // AHB-to-APB bridge
    // --------------------------------------------------
    ahb_to_apb_bridge bridge (
        .HCLK      (HCLK),
        .HRESETn   (HRESETn),
        .HADDR     (HADDR),
        .HTRANS    (HTRANS),
        .HWRITE    (HWRITE),
        .HSIZE     (HSIZE),
        .HSEL      (HSEL),
        .HREADY    (HREADY),
        .HWDATA    (HWDATA),
        .HRDATA    (HRDATA),
        .HREADYOUT (HREADYOUT),
        .HRESP     (HRESP),
        .PSEL      (PSEL),
        .PENABLE   (PENABLE),
        .PWRITE    (PWRITE),
        .PADDR     (PADDR),
        .PWDATA    (PWDATA),
        .PSTRB     (PSTRB),
        .PRDATA    (PRDATA),
        .PREADY    (PREADY),
        .PSLVERR   (PSLVERR)
    );

    // Single-master/single-slave ready feedback
    assign HREADY = HREADYOUT;

    // --------------------------------------------------
    // APB address decoder
    //
    // 0x0000_0XXX : APB memory
    // 0x0000_1XXX : APB timer
    // Other       : unmapped-address error
    // --------------------------------------------------
    assign PSEL_MEM =
        PSEL && (PADDR[15:12] == 4'h0);

    assign PSEL_TIMER =
        PSEL && (PADDR[15:12] == 4'h1);

    // --------------------------------------------------
    // APB response mux
    // --------------------------------------------------
    always_comb begin
        PRDATA  = 32'b0;
        PREADY  = 1'b1;
        PSLVERR = 1'b0;

        if (PSEL_MEM) begin
            PRDATA  = PRDATA_MEM;
            PREADY  = PREADY_MEM;
            PSLVERR = PSLVERR_MEM;
        end
        else if (PSEL_TIMER) begin
            PRDATA  = PRDATA_TIMER;
            PREADY  = PREADY_TIMER;
            PSLVERR = PSLVERR_TIMER;
        end
        else if (PSEL && PENABLE) begin
            // Complete unmapped access with an error.
            PREADY  = 1'b1;
            PSLVERR = 1'b1;
        end
    end

    // --------------------------------------------------
    // APB memory slave
    // --------------------------------------------------
    apb_slave slave (
        .pclk    (HCLK),
        .presetn (HRESETn),
        .paddr   (PADDR),
        .psel    (PSEL_MEM),
        .penable (PENABLE),
        .pwrite  (PWRITE),
        .pwdata  (PWDATA),
        .pstrb   (PSTRB),
        .prdata  (PRDATA_MEM),
        .pready  (PREADY_MEM),
        .pslverr (PSLVERR_MEM)
    );

    // --------------------------------------------------
    // APB timer peripheral
    // --------------------------------------------------
    apb_timer timer (
        .pclk    (HCLK),
        .presetn (HRESETn),
        .paddr   (PADDR),
        .psel    (PSEL_TIMER),
        .penable (PENABLE),
        .pwrite  (PWRITE),
        .pstrb   (PSTRB),
        .pwdata  (PWDATA),
        .prdata  (PRDATA_TIMER),
        .pready  (PREADY_TIMER),
        .pslverr (PSLVERR_TIMER)
    );

    // --------------------------------------------------
    // APB wait-state stability monitor
    // --------------------------------------------------
    always @(posedge HCLK) begin
        if (!HRESETn) begin
            stalled_prev <= 1'b0;
            saved_paddr  <= '0;
            saved_pwdata <= '0;
            saved_pstrb  <= '0;
            saved_pwrite <= 1'b0;
        end
        else begin
            if (stalled_prev) begin
                if (!PSEL || !PENABLE ||
                    PADDR  !== saved_paddr  ||
                    PWRITE !== saved_pwrite ||
                    PWDATA !== saved_pwdata ||
                    PSTRB  !== saved_pstrb) begin

                    errors = errors + 1;
                    $error("FAIL: APB signals changed during wait");
                end
            end

            stalled_prev <= PSEL && PENABLE && !PREADY;

            if (PSEL && PENABLE && !PREADY) begin
                saved_paddr  <= PADDR;
                saved_pwdata <= PWDATA;
                saved_pstrb  <= PSTRB;
                saved_pwrite <= PWRITE;
            end
        end
    end

    // --------------------------------------------------
    // Self-checking helper tasks
    // --------------------------------------------------
    task automatic check_data(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string test_name
    );
        begin
            checks = checks + 1;

            if (actual !== expected) begin
                errors = errors + 1;
                $error(
                    "FAIL: %s expected=%08h actual=%08h",
                    test_name, expected, actual
                );
            end
            else begin
                $display(
                    "PASS: %s = %08h",
                    test_name, actual
                );
            end
        end
    endtask

   
task automatic run_command(
    input logic        wr,
    input logic [31:0] address,
    input logic [31:0] data,
    input logic        expect_error
);
    integer timeout_count;
    begin
        @(negedge HCLK);
        write = wr;
        addr  = address;
        wdata = data;
        size  = 3'b010;
        start = 1'b1;

        @(negedge HCLK);
        start = 1'b0;

        timeout_count = 0;

        while (done !== 1'b1 && timeout_count < 100) begin
            @(negedge HCLK);
            timeout_count = timeout_count + 1;
        end

        if (done !== 1'b1) begin
            $fatal(1, "TIMEOUT: address=%08h write=%0b",
                   address, wr);
        end

        checks = checks + 1;

        if (error === expect_error) begin
            $display("PASS: address=%08h error=%0b expected=%0b",
                     address, error, expect_error);
        end
        else begin
            errors = errors + 1;
            $error("FAIL: address=%08h error=%0b expected=%0b",
                   address, error, expect_error);
        end

        @(negedge HCLK);
    end
endtask


    // --------------------------------------------------
    // Main test sequence
    // --------------------------------------------------

    initial begin
    $dumpfile("ahb_apb_system.vcd");
    $dumpvars(0, tb_ahb_apb_system);
    end
    
    initial begin
        HRESETn = 1'b0;

        start = 1'b0;
        write = 1'b0;
        addr  = '0;
        wdata = '0;
        size  = 3'b010;

        repeat (3) @(negedge HCLK);
        HRESETn = 1'b1;

        // TEST 1: Write memory register 0.
        $display("\nTEST 1: APB memory write");
        run_command(
            1'b1, 32'h0000_0000, 32'hCAFE_BABE, 1'b0
        );

        // TEST 2: Read memory register 0.
        $display("\nTEST 2: APB memory readback");
        run_command(
            1'b0, 32'h0000_0000, 32'b0, 1'b0
        );
        check_data(
            rdata, 32'hCAFE_BABE,
            "Memory register 0 readback"
        );

        // TEST 3: Write and read memory register 1.
        $display("\nTEST 3: Second memory register");
        run_command(
            1'b1, 32'h0000_0004, 32'h1234_5678, 1'b0
        );
        run_command(
            1'b0, 32'h0000_0004, 32'b0, 1'b0
        );
        check_data(
            rdata, 32'h1234_5678,
            "Memory register 1 readback"
        );

        // TEST 4: Enable timer.
        $display("\nTEST 4: Timer enable");
        run_command(
            1'b1, 32'h0000_1000, 32'h0000_0001, 1'b0
        );

        // TEST 5: Read timer control register.
        $display("\nTEST 5: Timer control readback");
        run_command(
            1'b0, 32'h0000_1000, 32'b0, 1'b0
        );
        check_data(
            rdata, 32'h0000_0001,
            "Timer control register"
        );

        // TEST 6: Read timer counter.
        $display("\nTEST 6: Timer counter increment");
        run_command(
            1'b0, 32'h0000_1004, 32'b0, 1'b0
        );

        checks = checks + 1;
        if (rdata > 32'd0)
            $display(
                "PASS: Timer counter incremented = %0d",
                rdata
            );
        else begin
            errors = errors + 1;
            $error("FAIL: Timer counter did not increment");
        end

        // TEST 7: Unmapped address should return an error.
        $display("\nTEST 7: Unmapped address error");
        run_command(
            1'b0, 32'h0000_2000, 32'b0, 1'b1
        );

        $display("\n==================================");
        $display("AHB-to-APB checks = %0d", checks);
        $display("AHB-to-APB errors = %0d", errors);
        $display("==================================");

        if (errors == 0)
            $display("ALL AHB-to-APB SYSTEM TESTS PASSED");
        else
            $fatal(1, "AHB-to-APB system test failed");

        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "TIMEOUT: AHB-to-APB system test");
    end

endmodule
