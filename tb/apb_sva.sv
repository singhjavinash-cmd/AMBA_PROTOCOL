
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

    logic        waiting;
    logic        saved_pwrite;
    logic [31:0] saved_paddr;
    logic [31:0] saved_pwdata;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            waiting     <= 1'b0;
            saved_pwrite <= 1'b0;
            saved_paddr  <= 32'b0;
            saved_pwdata <= 32'b0;
        end else begin
            if (psel && !penable) begin
                waiting      <= 1'b0;
                saved_pwrite <= pwrite;
                saved_paddr  <= paddr;
                saved_pwdata <= pwdata;
            end else if (psel && penable && !pready) begin
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
