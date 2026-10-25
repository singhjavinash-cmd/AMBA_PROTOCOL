
`timescale 1ns/1ps

module apb_subsystem (
    input  logic        clk,
    input  logic        resetn,

    // AXI4-Lite Write Address Channel
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    // AXI4-Lite Write Response Channel
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    // AXI4-Lite Read Data Channel
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // APB debug / verification outputs
    output logic [31:0] dbg_paddr,
    output logic        dbg_psel,
    output logic        dbg_penable,
    output logic        dbg_pwrite,
    output logic [31:0] dbg_pwdata,
    output logic [3:0]  dbg_pstrb,
    output logic [31:0] dbg_prdata,
    output logic        dbg_pready,
    output logic        dbg_pslverr
);

    // Internal APB master signals
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    // Peripheral selects
    logic psel_mem;
    logic psel_timer;
    logic psel_unmapped;

    // Peripheral response signals
    logic [31:0] prdata_mem;
    logic [31:0] prdata_timer;

    logic pready_mem;
    logic pready_timer;

    logic pslverr_mem;
    logic pslverr_timer;

    logic mem_addr_valid;
    logic timer_addr_valid;

    // =====================================================
    // AXI4-Lite to APB4 Bridge
    // =====================================================

    axi_to_apb_bridge bridge_inst (
        .clk             (clk),
        .resetn          (resetn),

        .s_axi_awaddr    (s_axi_awaddr),
        .s_axi_awvalid   (s_axi_awvalid),
        .s_axi_awready   (s_axi_awready),

        .s_axi_wdata     (s_axi_wdata),
        .s_axi_wstrb     (s_axi_wstrb),
        .s_axi_wvalid    (s_axi_wvalid),
        .s_axi_wready    (s_axi_wready),

        .s_axi_bresp     (s_axi_bresp),
        .s_axi_bvalid    (s_axi_bvalid),
        .s_axi_bready    (s_axi_bready),

        .s_axi_araddr    (s_axi_araddr),
        .s_axi_arvalid   (s_axi_arvalid),
        .s_axi_arready   (s_axi_arready),

        .s_axi_rdata     (s_axi_rdata),
        .s_axi_rresp     (s_axi_rresp),
        .s_axi_rvalid    (s_axi_rvalid),
        .s_axi_rready    (s_axi_rready),

        .m_apb_paddr     (paddr),
        .m_apb_psel      (psel),
        .m_apb_penable   (penable),
        .m_apb_pwrite    (pwrite),
        .m_apb_pwdata     (pwdata),
        .m_apb_pstrb     (pstrb),

        .m_apb_prdata    (prdata),
        .m_apb_pready    (pready),
        .m_apb_pslverr   (pslverr)
    );

    // =====================================================
    // Address Decoder
    // =====================================================

    // Memory: 16 aligned 32-bit words, 0x0000-0x003C
    assign mem_addr_valid =
        (paddr[31:6] == 26'b0) &&
        (paddr[1:0]  == 2'b00);

    // Timer: control at 0x1000, counter at 0x1004
    assign timer_addr_valid =
        (paddr == 32'h0000_1000) ||
        (paddr == 32'h0000_1004);

    assign psel_mem =
        psel && mem_addr_valid;

    assign psel_timer =
        psel && timer_addr_valid;

    assign psel_unmapped =
        psel && !(psel_mem || psel_timer);

    // =====================================================
    // APB Response Multiplexer
    // =====================================================

    always_comb begin
        prdata  = 32'b0;
        pready  = 1'b0;
        pslverr = 1'b0;

        if (psel_mem) begin
            prdata  = prdata_mem;
            pready  = pready_mem;
            pslverr = pslverr_mem;
        end
        else if (psel_timer) begin
            prdata  = prdata_timer;
            pready  = pready_timer;
            pslverr = pslverr_timer;
        end
        else if (psel_unmapped) begin
            // Invalid address completes during ACCESS
            pready  = penable;
            pslverr = 1'b1;
            prdata  = 32'hDEAD_DEAD;
        end
    end

    // =====================================================
    // APB Memory Slave
    // =====================================================

    apb_slave slave_mem (
        .pclk     (clk),
        .presetn  (resetn),
        .paddr    (paddr),
        .psel     (psel_mem),
        .penable  (penable),
        .pwrite   (pwrite),
        .pwdata   (pwdata),
        .pstrb    (pstrb),

        .prdata   (prdata_mem),
        .pready   (pready_mem),
        .pslverr  (pslverr_mem)
    );

    // =====================================================
    // APB Timer Peripheral
    // =====================================================

    apb_timer slave_timer (
        .pclk     (clk),
        .presetn  (resetn),
        .paddr    (paddr),
        .psel     (psel_timer),
        .penable  (penable),
        .pwrite   (pwrite),
        .pstrb    (pstrb),
        .pwdata   (pwdata),

        .prdata   (prdata_timer),
        .pready   (pready_timer),
        .pslverr  (pslverr_timer)
    );

    // =====================================================
    // Debug Outputs for Testbench and Waveforms
    // =====================================================

    assign dbg_paddr   = paddr;
    assign dbg_psel    = psel;
    assign dbg_penable = penable;
    assign dbg_pwrite  = pwrite;
    assign dbg_pwdata  = pwdata;
    assign dbg_pstrb   = pstrb;
    assign dbg_prdata  = prdata;
    assign dbg_pready  = pready;
    assign dbg_pslverr = pslverr;

endmodule
