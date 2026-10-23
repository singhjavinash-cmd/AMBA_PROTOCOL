
`timescale 1ns/1ps

// Simulation-only APB protocol checker.
// This module is intended for verification, not synthesis.

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

    logic        waiting;
    logic        saved_pwrite;
    logic [31:0] saved_paddr;
    logic [31:0] saved_pwdata;

    // Use always rather than always_ff because this checker
    // contains simulation-only system tasks ($error).
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            waiting       <= 1'b0;
            saved_pwrite  <= 1'b0;
            saved_paddr   <= 32'b0;
            saved_pwdata  <= 32'b0;
        end else begin
            if (psel && !penable) begin
                // Capture signals during SETUP.
                waiting      <= 1'b0;
                saved_pwrite <= pwrite;
                saved_paddr  <= paddr;
                saved_pwdata <= pwdata;
            end else if (psel && penable && !pready) begin
                // During a wait state, transfer controls must
                // remain stable until the transfer completes.
                if (!waiting) begin
                    saved_pwrite <= pwrite;
                    saved_paddr  <= paddr;
                    saved_pwdata <= pwdata;
                    waiting      <= 1'b1;
                end else begin
                    if (pwrite !== saved_pwrite)
                        $error("[APB CHECK] PWRITE changed during wait state");

                    if (paddr !== saved_paddr)
                        $error("[APB CHECK] PADDR changed during wait state");

                    if (pwrite && (pwdata !== saved_pwdata))
                        $error("[APB CHECK] PWDATA changed during wait state");
                end
            end else begin
                waiting <= 1'b0;
            end
        end
    end

endmodule
