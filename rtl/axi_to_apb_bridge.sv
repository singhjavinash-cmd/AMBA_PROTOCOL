
`timescale 1ns/1ps

module axi_to_apb_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  resetn,

    // AXI4-Lite Write Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  logic [DATA_WIDTH-1:0] s_axi_wdata,
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,

    // AXI4-Lite Write Response Channel
    output logic [1:0]            s_axi_bresp,
    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,

    // AXI4-Lite Read Data Channel
    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready,

    // APB Master Interface
    output logic [ADDR_WIDTH-1:0] m_apb_paddr,
    output logic                  m_apb_psel,
    output logic                  m_apb_penable,
    output logic                  m_apb_pwrite,
    output logic [DATA_WIDTH-1:0] m_apb_pwdata,
    input  logic [DATA_WIDTH-1:0] m_apb_prdata,
    input  logic                  m_apb_pready,
    input  logic                  m_apb_pslverr
);

    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        APB_SETUP   = 3'b001,
        APB_ACCESS  = 3'b010,
        AXI_WR_RESP = 3'b011,
        AXI_RD_RESP = 3'b100
    } state_t;

    state_t state;

    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [DATA_WIDTH-1:0] data_reg;

    logic is_write;
    logic write_error_reg;
    logic read_error_reg;

    logic aw_pending;
    logic w_pending;

    logic aw_hs;
    logic w_hs;
    logic ar_hs;
    logic write_available;

    logic [ADDR_WIDTH-1:0] awaddr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;

    // AXI ready signals
    assign s_axi_awready =
        resetn && (state == IDLE) && !aw_pending;

    assign s_axi_wready =
        resetn && (state == IDLE) && !w_pending;

    // Give priority to an already-started write transaction.
    assign s_axi_arready =
        resetn && (state == IDLE) &&
        !aw_pending && !w_pending &&
        !s_axi_awvalid && !s_axi_wvalid;

    assign aw_hs = s_axi_awvalid && s_axi_awready;
    assign w_hs  = s_axi_wvalid  && s_axi_wready;
    assign ar_hs = s_axi_arvalid && s_axi_arready;

    assign write_available =
        (aw_pending || aw_hs) &&
        (w_pending  || w_hs);

    // Independent AXI response registers
    assign s_axi_bresp = write_error_reg ? 2'b10 : 2'b00;
    assign s_axi_rresp = read_error_reg  ? 2'b10 : 2'b00;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state            <= IDLE;

            addr_reg         <= '0;
            data_reg         <= '0;
            awaddr_reg       <= '0;
            wdata_reg        <= '0;

            is_write         <= 1'b0;
            write_error_reg  <= 1'b0;
            read_error_reg   <= 1'b0;

            aw_pending       <= 1'b0;
            w_pending        <= 1'b0;

            s_axi_bvalid     <= 1'b0;
            s_axi_rvalid     <= 1'b0;
            s_axi_rdata      <= '0;

            m_apb_paddr      <= '0;
            m_apb_psel       <= 1'b0;
            m_apb_penable    <= 1'b0;
            m_apb_pwrite     <= 1'b0;
            m_apb_pwdata     <= '0;

        end else begin

            // Capture AXI write address independently
            if (aw_hs) begin
                awaddr_reg <= s_axi_awaddr;
                aw_pending <= 1'b1;
            end

            // Capture AXI write data independently
            if (w_hs) begin
                wdata_reg <= s_axi_wdata;
                w_pending <= 1'b1;
            end

            case (state)

                IDLE: begin
                    if (write_available) begin
                        // Use captured values when a channel
                        // was accepted in an earlier cycle.
                        addr_reg <= aw_pending
                                  ? awaddr_reg : s_axi_awaddr;

                        data_reg <= w_pending
                                  ? wdata_reg : s_axi_wdata;

                        is_write        <= 1'b1;
                        write_error_reg <= 1'b0;

                        aw_pending <= 1'b0;
                        w_pending  <= 1'b0;

                        state <= APB_SETUP;

                    end else if (ar_hs) begin
                        addr_reg       <= s_axi_araddr;
                        is_write       <= 1'b0;
                        read_error_reg <= 1'b0;

                        state <= APB_SETUP;
                    end
                end

                APB_SETUP: begin
                    m_apb_psel    <= 1'b1;
                    m_apb_penable <= 1'b0;
                    m_apb_paddr   <= addr_reg;
                    m_apb_pwrite  <= is_write;

                    if (is_write)
                        m_apb_pwdata <= data_reg;

                    state <= APB_ACCESS;
                end

                APB_ACCESS: begin
                    m_apb_penable <= 1'b1;

                    // Complete only during an active APB access.
                    if (m_apb_penable && m_apb_pready) begin
                        m_apb_psel    <= 1'b0;
                        m_apb_penable <= 1'b0;

                        if (is_write) begin
                            write_error_reg <= m_apb_pslverr;
                            s_axi_bvalid    <= 1'b1;
                            state           <= AXI_WR_RESP;
                        end else begin
                            read_error_reg <= m_apb_pslverr;
                            s_axi_rdata    <= m_apb_prdata;
                            s_axi_rvalid   <= 1'b1;
                            state          <= AXI_RD_RESP;
                        end
                    end
                end

                AXI_WR_RESP: begin
                    // Keep BRESP and BVALID stable until handshake.
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        state        <= IDLE;
                    end
                end

                AXI_RD_RESP: begin
                    // Keep RDATA, RRESP and RVALID stable until handshake.
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        state        <= IDLE;
                    end
                end

                default: begin
                    state         <= IDLE;
                    m_apb_psel    <= 1'b0;
                    m_apb_penable <= 1'b0;
                    s_axi_bvalid  <= 1'b0;
                    s_axi_rvalid  <= 1'b0;
                    aw_pending    <= 1'b0;
                    w_pending     <= 1'b0;
                end

            endcase
        end
    end

endmodule
