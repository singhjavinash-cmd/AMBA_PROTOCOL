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

            // Rule 1: Setup phase must be followed by Access.
            if (setup_seen && !(psel && penable)) begin
                $error(
                    "[APB CHECK] Setup was not followed by Access at %0t",
                    $time
                );
            end

            // Rule 2: During consecutive wait cycles,
            // the APB transfer controls must remain stable.
            // Do not flag the cycle in which the transfer completes.
            if (access_wait_seen && psel && penable && !pready) begin
                if ((paddr !== saved_addr) ||
                    (pwrite !== saved_write) ||
                    (saved_write && (pwdata !== saved_wdata))) begin
                    $error(
                        "[APB CHECK] Address/control/data changed during wait state at %0t",
                        $time
                    );
                end
            end

            // Record the current Setup phase.
            setup_seen <= psel && !penable;

            // Record the current Access wait state.
            access_wait_seen <= psel && penable && !pready;

            // Save the transfer controls during Access.
            if (psel && penable) begin
                saved_addr  <= paddr;
                saved_write <= pwrite;
                saved_wdata <= pwdata;
            end
        end
    end

endmodule