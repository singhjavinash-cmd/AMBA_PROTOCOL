`timescale 1ns/1ps

module apb_sva (
    input logic        pclk,
    input logic        presetn,
    input logic        psel,
    input logic        penable,
    input logic        pwrite,
    input logic [31:0] paddr,
    input logic [31:0] pwdata,
    input logic        pready
);

    logic setup_seen;
    logic access_wait_seen;

    logic [31:0] saved_addr;
    logic [31:0] saved_wdata;
    logic        saved_write;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            setup_seen       <= 1'b0;
            access_wait_seen <= 1'b0;
            saved_addr       <= 32'b0;
            saved_wdata      <= 32'b0;
            saved_write      <= 1'b0;
        end else begin

            // Rule 1: Setup must transition to Access
            if (setup_seen && !(psel && penable)) begin
                $error(
                    "[APB CHECK] Setup was not followed by Access at %0t",
                    $time
                );
            end

            // Rule 2: Transfer controls must remain stable
            // while the previous Access cycle was waiting.
            if (access_wait_seen) begin
                if (!(psel && penable)) begin
                    $error(
                        "[APB CHECK] Access ended before PREADY at %0t",
                        $time
                    );
                end else if (
                    (paddr !== saved_addr) ||
                    (pwrite !== saved_write) ||
                    (saved_write && (pwdata !== saved_wdata))
                ) begin
                    $error(
                        "[APB CHECK] Transfer signals changed during wait state at %0t",
                        $time
                    );
                end
            end

            // Remember whether the current cycle is Setup
            setup_seen <= psel && !penable;

            // Remember whether the current cycle is waiting
            access_wait_seen <= psel && penable && !pready;

            // Save transfer signals during Access
            if (psel && penable) begin
                saved_addr  <= paddr;
                saved_write <= pwrite;
                saved_wdata <= pwdata;
            end
        end
    end

endmodule