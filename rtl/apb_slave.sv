
`timescale 1ns/1ps

module apb_slave (
    input  logic        pclk,
    input  logic        presetn,

    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    input  logic [3:0]  pstrb,

    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr
);

    // 16 words x 32 bits = 64 bytes
    logic [31:0] reg_bank [0:15];

    logic [3:0] reg_idx;
    logic [1:0] wait_count;
    logic addr_valid;

    integer i;

    // Support aligned word addresses from 0x00 to 0x3C.
    assign addr_valid =
        (paddr[1:0]  == 2'b00) &&
        (paddr[31:6] == 26'b0);

    assign reg_idx = paddr[5:2];

    // Complete after two stalled ACCESS cycles.
    assign pready =
        presetn &&
        psel &&
        penable &&
        (wait_count == 2'd2);

    // Signal an error only on a completing invalid access.
    assign pslverr =
        pready && !addr_valid;

    // Invalid reads return zero.
    assign prdata =
        addr_valid ? reg_bank[reg_idx] : 32'b0;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            for (i = 0; i < 16; i = i + 1)
                reg_bank[i] <= 32'b0;

            wait_count <= 2'd0;
        end else begin

            if (!psel || !penable) begin
                // Clear counter outside APB ACCESS.
                wait_count <= 2'd0;
            end else if (!pready) begin
                // Insert two wait cycles.
                wait_count <= wait_count + 1'b1;
            end else begin
                // Transfer completes on this rising edge.
                wait_count <= 2'd0;

                // Write only to valid memory locations.
                if (pwrite && addr_valid) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        if (pstrb[i]) begin
                            reg_bank[reg_idx][i*8 +: 8]
                                <= pwdata[i*8 +: 8];
                        end
                    end
                end
            end
        end
    end

endmodule
