`timescale 1ns/1ps

module apb_timer (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr
);

    logic [31:0] ctrl_reg;
    logic [31:0] timer_count;
    wire  [1:0]  reg_offset = paddr[3:2];

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    // Continuous assignment avoids Icarus part-select warning
    assign prdata = (reg_offset == 2'b00) ? ctrl_reg :
                    (reg_offset == 2'b01) ? timer_count : 32'h0;

    // Sequential counter and register update
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            ctrl_reg    <= 32'h0;
            timer_count <= 32'h0;
        end else begin
            // Increment timer when enabled
            if (ctrl_reg[0]) begin
                timer_count <= timer_count + 1'b1;
            end

            // APB Write: qualified by psel and penable
            if (psel && penable && pwrite) begin
                if (reg_offset == 2'b00)
                    ctrl_reg <= pwdata;
                else if (reg_offset == 2'b01)
                    timer_count <= pwdata;
            end
        end
    end

endmodule