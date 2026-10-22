
`timescale 1ns/1ps

module tb_apb_sva_valid;

    logic pclk = 0;
    logic presetn = 0;
    logic psel = 0;
    logic penable = 0;
    logic pwrite = 0;
    logic [31:0] paddr = 0;
    logic [31:0] pwdata = 0;
    logic pready = 0;

    apb_sva dut (
        .pclk(pclk),
        .presetn(presetn),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .pready(pready)
    );

    always #5 pclk = ~pclk;

    initial begin
        $display("[TEST] Valid APB transaction");

        // Reset
        presetn = 0;
        repeat (2) @(negedge pclk);
        presetn = 1;

        // Setup phase
        @(negedge pclk);
        psel = 1;
        penable = 0;
        pwrite = 1;
        paddr = 32'h0000_0004;
        pwdata = 32'h1234_ABCD;
        pready = 0;

        // Access phase with wait state
        @(negedge pclk);
        penable = 1;
        pready = 0;

        // Keep signals stable during wait
        @(negedge pclk);
        pready = 1;

        // Complete transfer, then return to idle
        @(negedge pclk);
        psel = 0;
        penable = 0;
        pready = 0;

        @(negedge pclk);
        $display("[PASS] Valid APB transfer completed without violations");
        $finish;
    end

endmodule
