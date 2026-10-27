
`timescale 1ns/1ps

module tb_apb;
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

    // APB slave instance
    apb_slave uut (
        .pclk    (pclk),
        .presetn (presetn),
        .paddr   (paddr),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .pwdata  (pwdata),
        .pstrb   (pstrb),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr)
    );

    always #5 pclk = ~pclk;

    task automatic apb_write(
        input logic [31:0] addr,
        input logic [31:0] data
    );
        @(negedge pclk);
        psel    = 1'b1;
        penable = 1'b0;
        pwrite  = 1'b1;
        paddr   = addr;
        pwdata  = data;
        pstrb   = 4'b1111;

        @(negedge pclk);
        penable = 1'b1;

        do begin
            @(posedge pclk);
        end while (!pready);

        if (pslverr)
            $display("APB WRITE ERROR: addr=%08h", addr);
        else
            $display("APB WRITE SUCCESS: addr=%08h data=%08h",
                     addr, data);

        @(negedge pclk);
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        pstrb   = 4'b0000;
    endtask

    task automatic apb_read(input logic [31:0] addr);
        @(negedge pclk);
        psel    = 1'b1;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = addr;
        pstrb   = 4'b0000;

        @(negedge pclk);
        penable = 1'b1;

        do begin
            @(posedge pclk);
        end while (!pready);

        if (pslverr)
            $display("APB READ ERROR: addr=%08h", addr);
        else
            $display("APB READ SUCCESS: addr=%08h data=%08h",
                     addr, prdata);

        @(negedge pclk);
        psel    = 1'b0;
        penable = 1'b0;
    endtask

    initial begin
        $dumpfile("apb_waveform.vcd");
        $dumpvars(0, tb_apb);

        pclk    = 1'b0;
        presetn = 1'b0;
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = '0;
        pwdata  = '0;
        pstrb   = '0;

        repeat (2) @(negedge pclk);
        presetn = 1'b1;

        apb_write(32'h0000_0000, 32'hA1B2_C3D4);
        apb_write(32'h0000_0004, 32'h5E6F_7A8B);

        apb_read(32'h0000_0000);
        apb_read(32'h0000_0004);

        repeat (2) @(negedge pclk);

        $display("APB basic test completed.");
        $finish;
    end

endmodule
