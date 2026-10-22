`timescale 1ns/1ps

module tb_apb_self_checking;
    logic        pclk;
    logic        presetn;
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    // Fixed array for Icarus Verilog compatibility (Registers 0 to 3)
    int error_count = 0;
    int pass_count  = 0;
    logic [31:0] golden_mem [0:3];

    // DUT Instantiation
    apb_slave uut (
        .pclk    (pclk),
        .presetn (presetn),
        .paddr   (paddr),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .pwdata  (pwdata),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr)
    );
    // Instantiate in tb_apb_self_checking.sv
apb_sva sva_inst (
    .pclk    (pclk),
    .presetn (presetn),
    .psel    (psel),
    .penable (penable),
    .pwrite  (pwrite),
    .paddr   (paddr),
    .pwdata  (pwdata),
    .pready  (pready)
);

    // Clock Generation (100 MHz -> 10ns period)
    always #5 pclk = ~pclk;

    // Self-checking Write Task
    task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge pclk);
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b1;
        paddr   <= addr;
        pwdata  <= data;

        @(posedge pclk);
        penable <= 1'b1;

        while (!pready) begin
            @(posedge pclk);
        end

        // Golden model update (addr[3:2] maps to 0..3)
        golden_mem[addr[3:2]] = data;

        @(posedge pclk);
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
    endtask

    // Self-checking Read Task
    task automatic apb_read_check(input logic [31:0] addr);
        logic [31:0] expected_data;

        @(posedge pclk);
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        paddr   <= addr;

        @(posedge pclk);
        penable <= 1'b1;

        while (!pready) begin
            @(posedge pclk);
        end

        @(posedge pclk);
        expected_data = golden_mem[addr[3:2]];

        if (prdata === expected_data) begin
            $display("[PASS] Addr: 0x%0h | Read: 0x%0h | Expected: 0x%0h", addr, prdata, expected_data);
            pass_count++;
        end else begin
            $error("[FAIL] Addr: 0x%0h | Read: 0x%0h | Expected: 0x%0h", addr, prdata, expected_data);
            error_count++;
        end

        psel    <= 1'b0;
        penable <= 1'b0;
    endtask

    initial begin
        pclk    = 0;
        presetn = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 0;
        pwdata  = 0;

        // Initialize golden memory
        golden_mem[0] = 32'h0;
        golden_mem[1] = 32'h0;
        golden_mem[2] = 32'h0;
        golden_mem[3] = 32'h0;

        repeat (2) @(posedge pclk);
        presetn = 1;
        @(posedge pclk);

        // Targeted register writes
        apb_write(32'h0, 32'hDEAD_BEEF);
        apb_write(32'h4, 32'hCAFE_BABE);
        apb_write(32'h8, 32'h1234_5678);
        apb_write(32'hC, 32'hAABB_CCDD);

        // Self-verifying reads
        apb_read_check(32'h0);
        apb_read_check(32'h4);
        apb_read_check(32'h8);
        apb_read_check(32'hC);

        repeat (2) @(posedge pclk);

        $display("-------------------------------------------");
        $display("FINAL VERIFICATION -> PASS: %0d | FAILS: %0d", pass_count, error_count);
        $display("-------------------------------------------");

        if (error_count == 0)
            $display(">> TEST STATUS: 100%% VERIFIED (ALL PASS) <<");
        else
            $fatal(1, ">> TEST STATUS: FAILED WITH MISMATCHES <<");

        $finish;
    end
endmodule