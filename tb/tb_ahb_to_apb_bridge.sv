
`timescale 1ns/1ps

module tb_ahb_to_apb_bridge;

    logic HCLK, HRESETn;

    // AHB-Lite interface
    logic [31:0] HADDR;
    logic [1:0]  HTRANS;
    logic        HWRITE;
    logic [2:0]  HSIZE;
    logic        HSEL, HREADY;
    logic [31:0] HWDATA;

    logic [31:0] HRDATA;
    logic        HREADYOUT, HRESP;

    // APB4 interface
    logic        PSEL, PENABLE, PWRITE;
    logic [31:0] PADDR, PWDATA;
    logic [3:0]  PSTRB;

    logic [31:0] PRDATA;
    logic        PREADY, PSLVERR;

    integer checks = 0;
    integer errors = 0;

    logic [31:0] saved_addr;
    logic [31:0] saved_wdata;
    logic [3:0]  saved_strb;
    logic        saved_write;

    ahb_to_apb_bridge dut (
        .HCLK      (HCLK),
        .HRESETn   (HRESETn),
        .HADDR     (HADDR),
        .HTRANS    (HTRANS),
        .HWRITE    (HWRITE),
        .HSIZE     (HSIZE),
        .HSEL      (HSEL),
        .HREADY    (HREADY),
        .HWDATA    (HWDATA),
        .HRDATA    (HRDATA),
        .HREADYOUT (HREADYOUT),
        .HRESP     (HRESP),
        .PSEL      (PSEL),
        .PENABLE   (PENABLE),
        .PWRITE    (PWRITE),
        .PADDR     (PADDR),
        .PWDATA    (PWDATA),
        .PSTRB     (PSTRB),
        .PRDATA    (PRDATA),
        .PREADY    (PREADY),
        .PSLVERR   (PSLVERR)
    );

    always #5 HCLK = ~HCLK;

    task automatic check(
        input logic condition,
        input string message
    );
        begin
            checks = checks + 1;

            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %s at time %0t", message, $time);
            end
            else begin
                $display("PASS: %s", message);
            end
        end
    endtask

    // Start a transfer and verify APB SETUP/ACCESS.
    task automatic start_transfer(
        input logic [31:0] address,
        input logic        is_write,
        input logic [2:0]  transfer_size,
        input logic [31:0] write_data
    );
        begin
            @(negedge HCLK);
            HADDR  = address;
            HTRANS = 2'b10; // NONSEQ
            HWRITE = is_write;
            HSIZE  = transfer_size;
            HSEL   = 1'b1;
            HREADY = 1'b1;
            HWDATA = write_data;

            // Address phase is accepted at the next rising edge.
            @(negedge HCLK);
            HSEL   = 1'b0;
            HTRANS = 2'b00;

            wait (PSEL === 1'b1);
            #1;

            check(PENABLE === 1'b0, "APB SETUP phase");
            check(PADDR === address, "APB address captured");
            check(PWRITE === is_write, "APB write control captured");

            @(negedge HCLK);
            #1;

            check(
                PSEL === 1'b1 && PENABLE === 1'b1,
                "APB ACCESS phase"
            );
        end
    endtask

    // Verify APB controls remain stable while PREADY is low.
    task automatic check_wait_stability;
        integer k;
        begin
            saved_addr  = PADDR;
            saved_wdata = PWDATA;
            saved_strb  = PSTRB;
            saved_write = PWRITE;

            PREADY = 1'b0;

            for (k = 0; k < 3; k = k + 1) begin
                @(negedge HCLK);
                #1;

                check(PSEL === 1'b1, "PSEL remains high during wait");
                check(PENABLE === 1'b1, "PENABLE remains high during wait");
                check(PADDR === saved_addr, "PADDR stable during wait");
                check(PWRITE === saved_write, "PWRITE stable during wait");
                check(PWDATA === saved_wdata, "PWDATA stable during wait");
                check(PSTRB === saved_strb, "PSTRB stable during wait");
            end
        end
    endtask

    // Complete APB transaction and check AHB response.
    task automatic complete_transfer(
        input logic [31:0] read_data,
        input logic        slave_error,
        input logic        is_write
    );
        begin
            @(negedge HCLK);
            PRDATA  = read_data;
            PSLVERR = slave_error;
            PREADY  = 1'b1;

            // Bridge samples APB completion on the rising edge.
            @(posedge HCLK);
            #1;

            // Deassert APB completion after sampling.
            PREADY  = 1'b0;
            PSLVERR = 1'b0;

            if (slave_error) begin
                // First ERROR response cycle.
                check(HREADYOUT === 1'b0,
                      "AHB ERROR cycle 1: HREADYOUT low");
                check(HRESP === 1'b1,
                      "AHB ERROR cycle 1: HRESP high");

                // Bridge transitions to ERR_FINAL at this edge.
                @(posedge HCLK);
                #1;

                check(HREADYOUT === 1'b1,
                      "AHB ERROR cycle 2: HREADYOUT high");
                check(HRESP === 1'b1,
                      "AHB ERROR cycle 2: HRESP high");
            end
            else begin
                check(HREADYOUT === 1'b1,
                      "AHB successful response completes");
                check(HRESP === 1'b0,
                      "AHB successful response has no error");

                if (!is_write) begin
                    check(HRDATA === read_data,
                          "AHB read data captured");
                end
            end

            // Return to IDLE before starting another transfer.
            @(negedge HCLK);
            #1;
        end
    endtask

    initial begin
        HCLK    = 1'b0;
        HRESETn = 1'b0;

        HADDR  = '0;
        HTRANS = 2'b00;
        HWRITE = 1'b0;
        HSIZE  = 3'b010;
        HSEL   = 1'b0;
        HREADY = 1'b1;
        HWDATA = '0;

        PRDATA  = '0;
        PREADY  = 1'b0;
        PSLVERR = 1'b0;

        repeat (3) @(negedge HCLK);
        HRESETn = 1'b1;

        // TEST 1: Word write and APB wait states.
        $display("\nTEST 1: Word write and wait-state stability");

        start_transfer(
            32'h0000_0010, 1'b1, 3'b010, 32'h1234_ABCD
        );

        check(PSTRB === 4'b1111, "Word write PSTRB = 1111");

        check_wait_stability();
        complete_transfer(32'b0, 1'b0, 1'b1);

        // TEST 2: Byte write to lane 1.
        $display("\nTEST 2: Byte-write strobe");

        start_transfer(
            32'h0000_0011, 1'b1, 3'b000, 32'h0000_AA00
        );

        check(PSTRB === 4'b0010, "Byte write PSTRB = 0010");
        complete_transfer(32'b0, 1'b0, 1'b1);

        // TEST 3: Halfword write at address offset 2.
        $display("\nTEST 3: Halfword-write strobe");

        start_transfer(
            32'h0000_0012, 1'b1, 3'b001, 32'h0055_0000
        );

        check(PSTRB === 4'b1100, "Upper halfword PSTRB = 1100");
        complete_transfer(32'b0, 1'b0, 1'b1);

        // TEST 4: Read transfer.
        $display("\nTEST 4: Read data");

        start_transfer(
            32'h0000_0020, 1'b0, 3'b010, 32'b0
        );

        complete_transfer(32'hCAFE_BABE, 1'b0, 1'b0);

        // TEST 5: APB error response propagation.
        $display("\nTEST 5: PSLVERR propagation");

        start_transfer(
            32'h0000_0030, 1'b1, 3'b010, 32'hDEAD_BEEF
        );

        complete_transfer(32'b0, 1'b1, 1'b1);

        $display("\n================================");
        $display("AHB-to-APB checks = %0d", checks);
        $display("AHB-to-APB errors = %0d", errors);
        $display("================================");

        if (errors == 0)
            $display("ALL AHB-to-APB EXTENDED TESTS PASSED");
        else
            $fatal(1, "AHB-to-APB testbench failed");

        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "TIMEOUT: AHB-to-APB bridge test");
    end

endmodule