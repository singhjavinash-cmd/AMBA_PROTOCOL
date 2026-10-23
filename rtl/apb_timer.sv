
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
    wire  [1:0]  reg_offset = paddr[3:2];

    integer i;

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    // Read control register or timer counter
    assign prdata = (reg_offset == 2'b00) ? ctrl_reg :
                    (reg_offset == 2'b01) ? timer_count :
                    32'h0000_0000;

    // Timer and APB register operations
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            ctrl_reg    <= 32'h0000_0000;
            timer_count <= 32'h0000_0000;
        end else begin

            // Increment timer while enabled.
            // An APB write to timer_count takes priority below.
            if (ctrl_reg[0]) begin
                timer_count <= timer_count + 1'b1;
            end

            // APB write with byte strobes
            if (psel && penable && pwrite) begin
                if (reg_offset == 2'b00) begin
                    // Control register: update selected bytes
                    for (i = 0; i < 4; i = i + 1) begin
                        if (pstrb[i]) begin
                            ctrl_reg[i*8 +: 8]
                                <= pwdata[i*8 +: 8];
                        end
                    end
                end else if (reg_offset == 2'b01) begin
                    // Timer counter: update selected bytes
                    for (i = 0; i < 4; i = i + 1) begin
                        if (pstrb[i]) begin
                            timer_count[i*8 +: 8]
                                <= pwdata[i*8 +: 8];
                        end
                    end
                end
            end
        end
    end

endmodule
