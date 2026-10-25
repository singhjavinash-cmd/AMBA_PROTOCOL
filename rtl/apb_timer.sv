
`timescale 1ns/1ps

module apb_timer (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [3:0]  pstrb,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr
);

    logic [31:0] ctrl_reg;
    logic [31:0] timer_count;
    logic        addr_valid;

    integer i;

    // Only these two aligned addresses are implemented.
    assign addr_valid =
        (paddr == 32'h0000_1000) ||
        (paddr == 32'h0000_1004);

    // Zero-wait-state APB peripheral.
    assign pready = presetn;

    // Error is asserted for an invalid address during APB ACCESS.
    assign pslverr =
        presetn && psel && penable && pready && !addr_valid;

    // Register read mux.
    always_comb begin
        prdata = 32'b0;

        if (paddr == 32'h0000_1000)
            prdata = ctrl_reg;
        else if (paddr == 32'h0000_1004)
            prdata = timer_count;
    end

    // Timer register updates.
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            ctrl_reg    <= 32'b0;
            timer_count <= 32'b0;
        end else begin

            // Increment while enabled.
            if (ctrl_reg[0])
                timer_count <= timer_count + 1'b1;

            // Write only on a completed, valid APB access.
            if (psel && penable && pready &&
                pwrite && addr_valid) begin

                if (paddr == 32'h0000_1000) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        if (pstrb[i])
                            ctrl_reg[i*8 +: 8]
                                <= pwdata[i*8 +: 8];
                    end
                end
                else if (paddr == 32'h0000_1004) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        if (pstrb[i])
                            timer_count[i*8 +: 8]
                                <= pwdata[i*8 +: 8];
                    end
                end
            end
        end
    end

endmodule
