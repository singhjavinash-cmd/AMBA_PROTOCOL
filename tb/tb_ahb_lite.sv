
`timescale 1ns/1ps

module tb_ahb_lite;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    logic HCLK;
    logic HRESETn;

    logic [ADDR_WIDTH-1:0] HADDR;
    logic [1:0] HTRANS;
    logic HWRITE;
    logic [2:0] HSIZE;
    logic HSEL;
    logic HREADY;
    logic [DATA_WIDTH-1:0] HWDATA;

    logic [DATA_WIDTH-1:0] HRDATA;
    logic HREADYOUT;
    logic HRESP;

    integer checks = 0;
    integer errors = 0;

    ahb_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_WORDS(256),
        .WAIT_CYCLES(1)
    ) dut (
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

    always #5 HCLK = ~HCLK;

    task automatic check_value(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string test_name
    );
        begin
            checks = checks + 1;

            if (actual !== expected) begin
                errors = errors + 1;
                $error(
                    "FAIL: %s | Expected=%08h Actual=%08h",
                    test_name, expected, actual
                );
            end
            else begin
                $display(
                    "PASS: %s | Value=%08h",
                    test_name, actual
                );
            end
        end
    endtask

    // AHB-Lite write task
    task automatic ahb_write(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [2:0] transfer_size
    );
        integer timeout_count;
        begin
            // Address/control phase
            @(negedge HCLK);
            HSEL   = 1'b1;
            HREADY = 1'b1;
            HTRANS = 2'b10; // NONSEQ
            HADDR  = address;
            HWRITE = 1'b1;
            HSIZE  = transfer_size;

            @(posedge HCLK);
            #1;

            // Write data phase
            @(negedge HCLK);
            HSEL   = 1'b0;
            HTRANS = 2'b00;
            HWDATA = data;

            timeout_count = 0;

            while (HREADYOUT !== 1'b1 && timeout_count < 20) begin
                @(negedge HCLK);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 20)
                $fatal(1, "TIMEOUT during write at address %08h", address);

            @(posedge HCLK);
            #1;
        end
    endtask

    // AHB-Lite read task
    task automatic ahb_read(
        input logic [31:0] address,
        input logic [31:0] expected
    );
        logic [31:0] read_value;
        integer timeout_count;
        begin
            // Address/control phase
            @(negedge HCLK);
            HSEL   = 1'b1;
            HREADY = 1'b1;
            HTRANS = 2'b10; // NONSEQ
            HADDR  = address;
            HWRITE = 1'b0;
            HSIZE  = 3'b010;

            @(posedge HCLK);
            #1;

            // Read data phase
            @(negedge HCLK);
            HSEL   = 1'b0;
            HTRANS = 2'b00;

            timeout_count = 0;

            while (HREADYOUT !== 1'b1 && timeout_count < 20) begin
                @(negedge HCLK);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 20)
                $fatal(1, "TIMEOUT during read at address %08h", address);

            #1;
            read_value = HRDATA;

            check_value(
                read_value,
                expected,
                $sformatf("Read address 0x%08h", address)
            );

            @(posedge HCLK);
            #1;
        end
    endtask

    initial begin
        HCLK   = 1'b0;
        HRESETn = 1'b0;
        HADDR  = '0;
        HTRANS = 2'b00;
        HWRITE = 1'b0;
        HSIZE  = 3'b010;
        HSEL   = 1'b0;
        HREADY = 1'b1;
        HWDATA = '0;

        repeat (3) @(posedge HCLK);
        @(negedge HCLK);
        HRESETn = 1'b1;

        // Test 1: Full-word write/read
        ahb_write(32'h0000_0000, 32'h1234_ABCD, 3'b010);
        ahb_read (32'h0000_0000, 32'h1234_ABCD);

        // Test 2: Second memory word
        ahb_write(32'h0000_0004, 32'hDEAD_BEEF, 3'b010);
        ahb_read (32'h0000_0004, 32'hDEAD_BEEF);

        // Test 3: Byte write at address offset 1
        ahb_write(32'h0000_0001, 32'h0000_00AA, 3'b000);
        ahb_read (32'h0000_0000, 32'h1234_AACD);

        // Test 4: Halfword write to upper 16 bits
        ahb_write(32'h0000_0002, 32'h0000_0055, 3'b001);
        ahb_read (32'h0000_0000, 32'h0055_AACD);

        $display("------------------------------------");
        $display("AHB-Lite checks = %0d", checks);
        $display("AHB-Lite errors = %0d", errors);
        $display("------------------------------------");

        if (errors == 0)
            $display("ALL AHB-LITE TESTS PASSED");
        else
            $fatal(1, "AHB-Lite testbench failed");

        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "TIMEOUT: AHB-Lite testbench did not finish");
    end

endmodule
