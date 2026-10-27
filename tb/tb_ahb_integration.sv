
`timescale 1ns/1ps

module tb_ahb_integration;

    logic HCLK;
    logic HRESETn;

    // Master command interface
    logic start;
    logic write;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [2:0] size;

    logic [31:0] rdata;
    logic busy;
    logic done;
    logic error;

    // Shared AHB-Lite bus
    logic [31:0] HADDR;
    logic [1:0] HTRANS;
    logic HWRITE;
    logic [2:0] HSIZE;
    logic HSEL;
    logic [31:0] HWDATA;

    logic [31:0] HRDATA;
    logic HREADY;
    logic HREADYOUT;
    logic HRESP;

    integer errors = 0;

    // AHB-Lite master
    ahb_lite_master master (
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

    // AHB-Lite slave
    ahb_lite_slave #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .MEM_WORDS(256),
        .WAIT_CYCLES(1)
    ) slave (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR),
        .HTRANS(HTRANS),
        .HWRITE(HWRITE),
        .HSIZE(HSIZE),
        .HSEL(HSEL),
        .HREADY(HREADY),
        .HWDATA(HWDATA),
        .HRDATA(HRDATA),
        .HREADYOUT(HREADYOUT),
        .HRESP(HRESP)
    );

    // Single-slave bus: HREADY follows slave ready.
    assign HREADY = HREADYOUT;

    always #5 HCLK = ~HCLK;

    task automatic check_value(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string label_text
    );
        begin
            if (actual !== expected) begin
                errors = errors + 1;
                $error(
                    "FAIL: %s expected=%08h actual=%08h",
                    label_text, expected, actual
                );
            end
            else begin
                $display(
                    "PASS: %s value=%08h",
                    label_text, actual
                );
            end
        end
    endtask

    task automatic issue_command(
        input logic wr,
        input logic [31:0] address,
        input logic [31:0] data
    );
        integer timeout_count;
        begin
            @(negedge HCLK);
            write = wr;
            addr = address;
            wdata = data;
            size = 3'b010;
            start = 1'b1;

            @(negedge HCLK);
            start = 1'b0;

            timeout_count = 0;
            while (done !== 1'b1 && timeout_count < 30) begin
                @(negedge HCLK);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 30)
                $fatal(1, "TIMEOUT: master command");

            if (error)
                $fatal(1, "AHB response error at address %08h", address);

            @(negedge HCLK);
        end
    endtask

    initial begin
        HCLK = 1'b0;
        HRESETn = 1'b0;

        start = 1'b0;
        write = 1'b0;
        addr = '0;
        wdata = '0;
        size = 3'b010;

        repeat (3) @(negedge HCLK);
        HRESETn = 1'b1;

        // Write a word, then read it back.
        issue_command(1'b1, 32'h0000_0000, 32'hCAFE_BABE);
        issue_command(1'b0, 32'h0000_0000, 32'h0000_0000);
        check_value(rdata, 32'hCAFE_BABE, "Master/slave readback");

        // Test another address.
        issue_command(1'b1, 32'h0000_0004, 32'h1234_5678);
        issue_command(1'b0, 32'h0000_0004, 32'h0000_0000);
        check_value(rdata, 32'h1234_5678, "Second address readback");

        $display("--------------------------------");
        $display("AHB integration errors = %0d", errors);

        if (errors == 0)
            $display("ALL AHB INTEGRATION TESTS PASSED");
        else
            $fatal(1, "AHB integration test failed");

        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Simulation timeout");
    end

endmodule
