
`timescale 1ns/1ps

module ahb_lite_slave #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter MEM_WORDS   = 256,
    parameter WAIT_CYCLES = 1
)(
    input  logic                  HCLK,
    input  logic                  HRESETn,

    input  logic [ADDR_WIDTH-1:0] HADDR,
    input  logic [1:0]            HTRANS,
    input  logic                  HWRITE,
    input  logic [2:0]            HSIZE,
    input  logic                  HSEL,
    input  logic                  HREADY,

    input  logic [DATA_WIDTH-1:0] HWDATA,

    output logic [DATA_WIDTH-1:0] HRDATA,
    output logic                  HREADYOUT,
    output logic                  HRESP
);

    localparam integer BYTE_LANES  = DATA_WIDTH / 8;
    localparam integer ADDR_LSB    = $clog2(BYTE_LANES);
    localparam integer INDEX_WIDTH = $clog2(MEM_WORDS);

    localparam logic [1:0] ERR_IDLE  = 2'b00;
    localparam logic [1:0] ERR_WAIT  = 2'b01;
    localparam logic [1:0] ERR_FINAL = 2'b10;

    logic [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];

    logic [ADDR_WIDTH-1:0] addr_reg;
    logic                  write_reg;
    logic [2:0]            size_reg;
    logic                  valid_reg;

    logic [1:0] error_state;

    integer wait_count;
    integer i;

    wire transfer_valid = HSEL && HREADY && HTRANS[1];

    wire [INDEX_WIDTH-1:0] word_index =
        addr_reg[ADDR_LSB + INDEX_WIDTH - 1 : ADDR_LSB];

    wire address_in_range =
        (addr_reg[ADDR_WIDTH-1 : ADDR_LSB + INDEX_WIDTH] == '0);

    // Ready and response generation.
    always_comb begin
        HREADYOUT = 1'b1;
        HRESP     = 1'b0;

        case (error_state)
            ERR_WAIT: begin
                HREADYOUT = 1'b0;
                HRESP     = 1'b1;
            end

            ERR_FINAL: begin
                HREADYOUT = 1'b1;
                HRESP     = 1'b1;
            end

            default: begin
                if (valid_reg && wait_count < WAIT_CYCLES)
                    HREADYOUT = 1'b0;
            end
        endcase
    end

    // Read data for the accepted address.
    always_comb begin
        HRDATA = '0;

        if (valid_reg && !write_reg && address_in_range)
            HRDATA = mem[word_index];
    end

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_reg    <= '0;
            write_reg   <= 1'b0;
            size_reg    <= 3'b010;
            valid_reg   <= 1'b0;
            wait_count  <= 0;
            error_state <= ERR_IDLE;

            for (i = 0; i < MEM_WORDS; i = i + 1)
                mem[i] <= '0;
        end
        else begin
            case (error_state)

                ERR_WAIT: begin
                    error_state <= ERR_FINAL;
                end

                ERR_FINAL: begin
                    error_state <= ERR_IDLE;
                    valid_reg   <= 1'b0;
                    wait_count  <= 0;
                end

                default: begin
                    if (valid_reg && wait_count < WAIT_CYCLES) begin
                        wait_count <= wait_count + 1;
                    end
                    else begin
                        wait_count <= 0;

                        if (valid_reg && !address_in_range) begin
                            error_state <= ERR_WAIT;
                            valid_reg   <= 1'b0;
                        end
                        else begin

                            // Complete the current write data phase.
                            if (valid_reg && write_reg &&
                                address_in_range && DATA_WIDTH == 32) begin

                                case (size_reg)

                                    // 32-bit word write.
                                    3'b010: begin
                                        if (addr_reg[1:0] == 2'b00)
                                            mem[word_index] <= HWDATA;
                                    end

                                    // 16-bit halfword write.
                                    3'b001: begin
                                        if (addr_reg[0] == 1'b0) begin
                                            if (addr_reg[1] == 1'b0)
                                                mem[word_index][15:0]
                                                    <= HWDATA[15:0];
                                            else
                                                mem[word_index][31:16]
                                                    <= HWDATA[15:0];
                                        end
                                    end

                                    // 8-bit byte write.
                                    3'b000: begin
                                        case (addr_reg[1:0])
                                            2'b00:
                                                mem[word_index][7:0]
                                                    <= HWDATA[7:0];

                                            2'b01:
                                                mem[word_index][15:8]
                                                    <= HWDATA[7:0];

                                            2'b10:
                                                mem[word_index][23:16]
                                                    <= HWDATA[7:0];

                                            2'b11:
                                                mem[word_index][31:24]
                                                    <= HWDATA[7:0];
                                        endcase
                                    end

                                    default: begin
                                        // Unsupported sizes are ignored.
                                    end
                                endcase
                            end

                            // Capture the next address/control phase
                            // only when the bus accepts the transfer.
                            if (transfer_valid) begin
                                addr_reg  <= HADDR;
                                write_reg <= HWRITE;
                                size_reg  <= HSIZE;
                                valid_reg <= 1'b1;
                            end
                            else begin
                                valid_reg <= 1'b0;
                            end
                        end
                    end
                end
            endcase
        end
    end

endmodule