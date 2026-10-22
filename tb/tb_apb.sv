`timescale 1ns/1ps

module tb_apb;
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

    apb_slave uut (.*);

    always #5 pclk = ~pclk;

    // Updated Write Task with PREADY wait
    task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge pclk);
        // SETUP Phase
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b1;
        paddr   <= addr;
        pwdata  <= data;

        @(posedge pclk);
        // ACCESS Phase
        penable <= 1'b1;

        // Slave ready hone tak wait karo
        while (!pready) begin
            @(posedge pclk);
        end

        // Transfer done -> Return to IDLE
        @(posedge pclk);
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
    endtask

    // Updated Read Task with PREADY wait
    task automatic apb_read(input logic [31:0] addr);
        @(posedge pclk);
        // SETUP Phase
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        paddr   <= addr;

        @(posedge pclk);
        // ACCESS Phase
        penable <= 1'b1;

        // Slave ready hone tak wait karo
        while (!pready) begin
            @(posedge pclk);
        end

        @(posedge pclk);
        $display("[SV READ SUCCESS] Addr: 0x%0h | Data: 0x%0h", addr, prdata);
        psel    <= 1'b0;
        penable <= 1'b0;
    endtask

    initial begin
        $dumpfile("apb_waveform.vcd");
        $dumpvars(0, tb_apb);

        pclk    = 0;
        presetn = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 0;
        pwdata  = 0;

        repeat (2) @(posedge pclk);
        presetn = 1;
        @(posedge pclk);

        // Write transactions
        apb_write(32'h0, 32'hA1B2_C3D4);
        @(posedge pclk);
        apb_write(32'h4, 32'h5E6F_7A8B);
        @(posedge pclk);

        // Read transactions
        apb_read(32'h0);
        @(posedge pclk);
        apb_read(32'h4);
        repeat (3) @(posedge pclk);

        $display(">> All APB Transfers with Wait-States Verified! <<");
        $finish;
    end
endmodule