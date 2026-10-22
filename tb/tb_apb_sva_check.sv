`timescale 1ns/1ps

module tb_apb_sva_check;

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
        $display("[TEST] APB wait-state stability violation");

        repeat (2) @(negedge pclk);
        presetn = 1;

        // Valid Setup phase
        @(negedge pclk);
        psel = 1;
        penable = 0;
        pwrite = 1;
        paddr = 32'h0000_0004;
        pwdata = 32'hAAAA_5555;

        // Enter Access with PREADY low
        @(negedge pclk);
        penable = 1;
        pready = 0;

        // Keep waiting for one cycle
        @(negedge pclk);

        // Deliberately violate stability during wait
        paddr = 32'h0000_0008;

        @(negedge pclk);

        $display("[TEST COMPLETE] Inspect output for stability error");
        $finish;
    end

    initial begin
        #500;
        $fatal(1, "[FAIL] Timeout");
    end

endmodule