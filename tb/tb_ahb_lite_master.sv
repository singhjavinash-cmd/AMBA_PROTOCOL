
`timescale 1ns/1ps

module tb_ahb_lite_master;

    logic HCLK, HRESETn;
    logic start, write;
    logic [31:0] addr, wdata;
    logic [2:0] size;

    logic [31:0] rdata;
    logic busy, done, error;

    logic [31:0] HADDR;
    logic [1:0] HTRANS;
    logic HWRITE;
    logic [2:0] HSIZE;
    logic HSEL;
    logic [31:0] HWDATA;

    logic [31:0] HRDATA;
    logic HREADY, HRESP;

    integer errors = 0;

    ahb_lite_master dut (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .start(start),
        .write(write),
        .addr(addr),
        .wdata(wdata),
        .size(size),
        .rdata(rdata),
        .busy(busy),
        .done(done),
        .error(error),
        .HADDR(HADDR),
        .HTRANS(HTRANS),
        .HWRITE(HWRITE),
        .HSIZE(HSIZE),
        .HSEL(HSEL),
        .HWDATA(HWDATA),
        .HRDATA(HRDATA),
        .HREADY(HREADY),
        .HRESP(HRESP)
    );

    always #5 HCLK = ~HCLK;

    task automatic check(input logic condition, input string message);
        begin
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $error("FAIL: %s", message);
            end
            else begin
                $display("PASS: %s", message);
            end
        end
    endtask

    task automatic start_command(
        input logic wr,
        input logic [31:0] a,
        input logic [31:0] d
    );
        begin
            @(negedge HCLK);
            write = wr;
            addr = a;
            wdata = d;
            size = 3'b010;
            start = 1'b1;

            @(negedge HCLK);
            start = 1'b0;
        end
    endtask

    task automatic wait_done;
        integer timeout_count;
        begin
            timeout_count = 0;
            while (done !== 1'b1 && timeout_count < 20) begin
                @(negedge HCLK);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 20)
                $fatal(1, "Master timed out");
        end
    endtask

    initial begin
        HCLK = 0;
        HRESETn = 0;

        start = 0;
        write = 0;
        addr = 0;
        wdata = 0;
        size = 3'b010;

        HRDATA = 0;
        HREADY = 1;
        HRESP = 0;

        repeat (3) @(negedge HCLK);
        HRESETn = 1;

        // Test 1: write command
        start_command(1'b1, 32'h0000_0010, 32'h1234_ABCD);

        wait (HSEL == 1'b1);
        check(HADDR == 32'h0000_0010, "Write address");
        check(HWRITE == 1'b1, "Write control");
        check(HWDATA == 32'h1234_ABCD, "Write data");
        check(HTRANS == 2'b10, "NONSEQ address transfer");

        wait_done();
        check(error == 1'b0, "Write completed without error");

        @(negedge HCLK);

        // Test 2: read command
        HRDATA = 32'hDEAD_BEEF;
        start_command(1'b0, 32'h0000_0020, 32'h0);

        wait (HSEL == 1'b1);
        check(HADDR == 32'h0000_0020, "Read address");
        check(HWRITE == 1'b0, "Read control");

        wait_done();
        check(rdata == 32'hDEAD_BEEF, "Read data captured");
        check(error == 1'b0, "Read completed without error");

        $display("--------------------------------");
        $display("AHB master errors = %0d", errors);

        if (errors == 0)
            $display("ALL AHB MASTER TESTS PASSED");
        else
            $fatal(1, "AHB master test failed");

        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Simulation timeout");
    end

endmodule
