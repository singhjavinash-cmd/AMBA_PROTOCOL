
`timescale 1ns/1ps

module ahb_lite_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                  HCLK,
    input  logic                  HRESETn,

    // Simple command interface
    input  logic                  start,
    input  logic                  write,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic [2:0]            size,

    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  busy,
    output logic                  done,
    output logic                  error,

    // AHB-Lite master interface
    output logic [ADDR_WIDTH-1:0] HADDR,
    output logic [1:0]            HTRANS,
    output logic                  HWRITE,
    output logic [2:0]            HSIZE,
    output logic                  HSEL,
    output logic [DATA_WIDTH-1:0] HWDATA,

    input  logic [DATA_WIDTH-1:0] HRDATA,
    input  logic                  HREADY,
    input  logic                  HRESP
);

    typedef enum logic [2:0] {
        IDLE,
        ADDRESS,
        DATA_PHASE,
        ERROR_SECOND,
        FINISH
    } state_t;

    state_t state;

    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [2:0] size_reg;
    logic write_reg;

    // --------------------------------------------------
    // Combinational AHB outputs
    // --------------------------------------------------
    always_comb begin
        HADDR  = addr_reg;
        HWRITE = write_reg;
        HSIZE  = size_reg;
        HWDATA = wdata_reg;

        HSEL   = 1'b0;
        HTRANS = 2'b00;

        busy = (state != IDLE);
        done = (state == FINISH);

        case (state)
            ADDRESS: begin
                HSEL   = 1'b1;
                HTRANS = 2'b10; // NONSEQ
            end

            default: begin
                HSEL   = 1'b0;
                HTRANS = 2'b00; // IDLE
            end
        endcase
    end

    // --------------------------------------------------
    // Sequential controller
    // --------------------------------------------------
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state     <= IDLE;
            addr_reg  <= '0;
            wdata_reg <= '0;
            size_reg  <= 3'b010;
            write_reg <= 1'b0;
            rdata     <= '0;
            error     <= 1'b0;
        end
        else begin
            case (state)

                IDLE: begin
                    error <= 1'b0;

                    if (start) begin
                        addr_reg  <= addr;
                        wdata_reg <= wdata;
                        size_reg  <= size;
                        write_reg <= write;
                        state     <= ADDRESS;
                    end
                end

                ADDRESS: begin
                    // Address phase is accepted only when
                    // the AHB bus is ready.
                    if (HREADY)
                        state <= DATA_PHASE;
                end

                DATA_PHASE: begin
                    // Wait until the transfer completes.
                    if (HREADY) begin
                        if (!write_reg)
                            rdata <= HRDATA;

                        // Capture the response on the
                        // completed data-phase cycle.
                        if (HRESP) begin
                            error <= 1'b1;

                            // AHB-Lite ERROR response has
                            // a second response cycle.
                            state <= ERROR_SECOND;
                        end
                        else begin
                            error <= 1'b0;
                            state <= FINISH;
                        end
                    end
                end

                ERROR_SECOND: begin
                    // The bridge's second ERROR cycle
                    // completes with HREADY high.
                    if (HREADY)
                        state <= FINISH;
                end

                FINISH: begin
                    // done is asserted while in FINISH.
                    // Return to IDLE on the next clock.
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    error <= 1'b0;
                end

            endcase
        end
    end

endmodule
