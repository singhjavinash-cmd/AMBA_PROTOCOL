
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

    logic [31:0] reg_bank [0:3];
    logic [1:0]  reg_idx;
    logic [1:0]  wait_count;
    integer i;

    assign reg_idx = paddr[3:2];
    assign pslverr = 1'b0;
    assign pready  = (wait_count == 2'd2);
    assign prdata  = reg_bank[reg_idx];

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_bank[0] <= 32'h0;
            reg_bank[1] <= 32'h0;
            reg_bank[2] <= 32'h0;
            reg_bank[3] <= 32'h0;
            wait_count  <= 2'd0;
        end else begin
            if (psel && penable) begin
                if (wait_count < 2'd2) begin
                    wait_count <= wait_count + 1'b1;
                end else begin
                    wait_count <= 2'd0;

                    if (pwrite) begin
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
