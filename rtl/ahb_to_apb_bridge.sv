
`timescale 1ns/1ps

module ahb_to_apb_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                    HCLK,
    input  logic                    HRESETn,

    // AHB-Lite interface
    input  logic [ADDR_WIDTH-1:0]   HADDR,
    input  logic [1:0]              HTRANS,
    input  logic                    HWRITE,
    input  logic [2:0]              HSIZE,
    input  logic                    HSEL,
    input  logic                    HREADY,
    input  logic [DATA_WIDTH-1:0]   HWDATA,

    output logic [DATA_WIDTH-1:0]   HRDATA,
    output logic                    HREADYOUT,
    output logic                    HRESP,

    // APB4 interface
    output logic                    PSEL,
    output logic                    PENABLE,
    output logic                    PWRITE,
    output logic [ADDR_WIDTH-1:0]   PADDR,
    output logic [DATA_WIDTH-1:0]   PWDATA,
    output logic [DATA_WIDTH/8-1:0] PSTRB,

    input  logic [DATA_WIDTH-1:0]   PRDATA,
    input  logic                    PREADY,
    input  logic                    PSLVERR
);

    localparam integer BYTE_LANES = DATA_WIDTH / 8;
    localparam integer ADDR_LSB   = $clog2(BYTE_LANES);

    typedef enum logic [2:0] {
        IDLE,
        SETUP,
        ACCESS,
        RESP,
        ERR_WAIT,
        ERR_FINAL
    } state_t;

    state_t state;

    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [DATA_WIDTH-1:0] rdata_reg;

    logic [2:0] size_reg;
    logic       write_reg;

    logic       unmapped_reg;
    logic       transfer_error;

    integer lane;

    // Address map:
    // 0x0000_0XXX : APB memory
    // 0x0000_1XXX : APB timer
    // Other addresses: return AHB ERROR.
    always_comb begin
        unmapped_reg = 1'b0;

        if ((addr_reg & 32'hFFFF_F000) != 32'h0000_0000 &&
            (addr_reg & 32'hFFFF_F000) != 32'h0000_1000)
            unmapped_reg = 1'b1;
    end

    // A valid AHB transfer is NONSEQ or SEQ,
    // selected and accepted while HREADY is high.
    wire ahb_transfer = HSEL && HREADY && HTRANS[1];

    // APB and AHB combinational outputs.
    always_comb begin
        PSEL      = 1'b0;
        PENABLE   = 1'b0;
        PWRITE    = write_reg;
        PADDR     = addr_reg;
        PWDATA    = wdata_reg;
        PSTRB     = '0;

        HREADYOUT = 1'b0;
        HRESP     = 1'b0;
        HRDATA    = rdata_reg;

        case (state)

            IDLE: begin
                HREADYOUT = 1'b1;
            end

            SETUP: begin
                if (!unmapped_reg) begin
                    PSEL    = 1'b1;
                    PENABLE = 1'b0;
                end
            end

            ACCESS: begin
                if (!unmapped_reg) begin
                    PSEL    = 1'b1;
                    PENABLE = 1'b1;

                    if (write_reg) begin
                        case (size_reg)

                            // Byte access
                            3'b000: begin
                                for (lane = 0;
                                     lane < BYTE_LANES;
                                     lane = lane + 1) begin
                                    if (lane == addr_reg[ADDR_LSB-1:0])
                                        PSTRB[lane] = 1'b1;
                                end
                            end

                            // Halfword access
                            3'b001: begin
                                if (DATA_WIDTH == 32) begin
                                    if (addr_reg[1] == 1'b0)
                                        PSTRB[1:0] = 2'b11;
                                    else
                                        PSTRB[3:2] = 2'b11;
                                end
                            end

                            // Word access
                            3'b010: begin
                                PSTRB = '1;
                            end

                            default: begin
                                PSTRB = '0;
                            end

                        endcase
                    end
                end
            end

            RESP: begin
                HREADYOUT = 1'b1;
                HRESP     = 1'b0;
                HRDATA    = rdata_reg;
            end

            // First cycle of AHB ERROR response.
            ERR_WAIT: begin
                HREADYOUT = 1'b0;
                HRESP     = 1'b1;
            end

            // Second cycle of AHB ERROR response.
            ERR_FINAL: begin
                HREADYOUT = 1'b1;
                HRESP     = 1'b1;
            end

            default: begin
                HREADYOUT = 1'b1;
            end

        endcase
    end

    // Sequential state machine.
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state     <= IDLE;
            addr_reg  <= '0;
            wdata_reg <= '0;
            rdata_reg <= '0;
            size_reg  <= 3'b010;
            write_reg <= 1'b0;
        end
        else begin
            case (state)

                IDLE: begin
                    if (ahb_transfer) begin
                        addr_reg  <= HADDR;
                        write_reg <= HWRITE;
                        size_reg  <= HSIZE;
                        state     <= SETUP;
                    end
                end

                SETUP: begin
                    if (unmapped_reg) begin
                        // No APB access for an unmapped address.
                        state <= ERR_WAIT;
                    end
                    else begin
                        // Capture and align AHB write data.
                        case (size_reg)
                            3'b000:
                                wdata_reg <=
                                    HWDATA << (addr_reg[ADDR_LSB-1:0] * 8);

                            3'b001:
                                wdata_reg <=
                                    HWDATA << (addr_reg[ADDR_LSB-1:0] * 8);

                            default:
                                wdata_reg <= HWDATA;
                        endcase

                        state <= ACCESS;
                    end
                end

                ACCESS: begin
                    // Wait for APB completion.
                    if (PREADY) begin
                        if (PSLVERR) begin
                            state <= ERR_WAIT;
                        end
                        else begin
                            if (!write_reg)
                                rdata_reg <= PRDATA;

                            state <= RESP;
                        end
                    end
                end

                RESP: begin
                    state <= IDLE;
                end

                ERR_WAIT: begin
                    state <= ERR_FINAL;
                end

                ERR_FINAL: begin
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
