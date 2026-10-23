
`timescale 1ns/1ps

module tb_apb_self_checking;

    logic        pclk;
    logic        presetn;
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    integer pass_count;
    integer fail_count;

    apb_slave uut (
        .pclk     (pclk),
        .presetn  (presetn),
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

    apb_sva sva_inst (
        .pclk     (pclk),
        .presetn  (presetn),
        .psel     (psel),
        .penable  (penable),
        .pwrite   (pwrite),
        .paddr    (paddr),
        .pwdata   (pwdata),
        .pready   (pready)
    );

    initial pclk = 1'b0;
    always #5 pclk = ~pclk;

    task automatic apb_write(
        input logic [31:0] addr,
        input logic [31:0] data
    );
        begin
            @(negedge pclk);
            paddr   = addr;
            pwdata  = data;
            pstrb   = 4'b1111;
            pwrite  = 1'b1;
            psel    = 1'b1;
            penable = 1'b0;

            @(negedge pclk);
            penable = 1'b1;

            // Wait for the slave's ready indication
            do begin
                @(posedge pclk);
            end while (pready !== 1'b1);

            @(negedge pclk);
            psel    = 1'b0;
            penable = 1'b0;
            pwrite  = 1'b0;
            pstrb   = 4'b0000;
        end
    endtask

    task automatic apb_read_check(
        input logic [31:0] addr,
        input logic [31:0] expected
    );
        logic [31:0] actual;
        begin
            @(negedge pclk);
            paddr   = addr;
            pwrite  = 1'b0;
            pstrb   = 4'b0000;
            psel    = 1'b1;
            penable = 1'b0;

            @(negedge pclk);
            penable = 1'b1;

            do begin
                @(posedge pclk);
            end while (pready !== 1'b1);

            // Sample after the active edge
            #1;
            actual = prdata;

            @(negedge pclk);
            psel    = 1'b0;
            penable = 1'b0;

            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("[PASS] Addr: %h | Read: %h",
                         addr, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] Addr: %h | Read: %h | Expected: %h",
                         addr, actual, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("apb_self_checking.vcd");
        $dumpvars(0, tb_apb_self_checking);

        presetn = 1'b0;
        paddr     = '0;
        psel      = 1'b0;
        penable   = 1'b0;
        pwrite    = 1'b0;
        pwdata    = '0;
        pstrb     = 4'b0000;
        pass_count = 0;
        fail_count = 0;

        repeat (3) @(negedge pclk);
        presetn = 1'b1;

        apb_write(32'h0000_0000, 32'hDEAD_BEEF);
        apb_write(32'h0000_0004, 32'hCAFE_BABE);
        apb_write(32'h0000_0008, 32'h1234_5678);
        apb_write(32'h0000_000C, 32'hAABB_CCDD);

        apb_read_check(32'h0000_0000, 32'hDEAD_BEEF);
        apb_read_check(32'h0000_0004, 32'hCAFE_BABE);
        apb_read_check(32'h0000_0008, 32'h1234_5678);
        apb_read_check(32'h0000_000C, 32'hAABB_CCDD);

        $display("------------------------------------------");
        $display("FINAL VERIFICATION -> PASS: %0d | FAILS: %0d",
                 pass_count, fail_count);
        $display("------------------------------------------");

        if (fail_count != 0)
            $fatal(1, "TEST STATUS: FAILED");
        else
            $display("TEST STATUS: PASSED");

        $finish;
    end

endmodule
