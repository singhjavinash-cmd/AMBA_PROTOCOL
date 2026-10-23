
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

    // 16 words = 64 bytes of memory
    logic [31:0] reg_bank [0:15];
    logic [3:0]  reg_idx;
    logic [1:0]  wait_count;
    integer i;

    // Word-aligned addresses: 0x00, 0x04, ... 0x3C
    assign reg_idx = paddr[5:2];

    assign pslverr = 1'b0;
    assign pready  = (wait_count == 2'd2);
    assign prdata  = reg_bank[reg_idx];

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            for (i = 0; i < 16; i = i + 1)
                reg_bank[i] <= 32'h0000_0000;

            wait_count <= 2'd0;
        end else begin
            if (psel && penable) begin
                if (wait_count < 2'd2) begin
                    wait_count <= wait_count + 1'b1;
                end else begin
                    wait_count <= 2'd0;

                    if (pwrite) begin
                        // Update only the selected byte lanes
                        for (i = 0; i < 4; i = i + 1) begin
                            if (pstrb[i]) begin
                                reg_bank[reg_idx][i*8 +: 8]
                                    <= pwdata[i*8 +: 8];
                            end
                        end
                    end
                end
            end else begin
                wait_count <= 2'd0;
            end
        end
    end

endmodule
