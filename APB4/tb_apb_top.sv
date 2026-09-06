// ==============================================================================
// Testbench: tb_apb_top.sv
// Connects APB Master to APB Slave and tests:
// 1. Reset values
// 2. Full 32-bit Write and Read
// 3. Byte Strobe updates
// 4. Read-Only violation detection (PSLVERR)
// 5. Unaligned address error detection (PSLVERR)
// ==============================================================================

`timescale 1ns/1ps

module tb_apb_top;

    logic        pclk;
    logic        presetn;

    // Master High-Level CPU Interface
    logic        req_valid;
    logic        req_write;
    logic [31:0] req_addr;
    logic [31:0] req_wdata;
    logic [3:0]  req_strb;
    logic        req_ready;
    logic [31:0] resp_rdata;
    logic        resp_err;
    logic        resp_valid;

    // APB4 Interconnect Signals
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
    logic        pready;
    logic [31:0] prdata;
    logic        pslverr;

    // Instantiate Master
    apb_master u_master (
        .pclk(pclk),
        .presetn(presetn),
        .req_valid(req_valid),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_strb(req_strb),
        .req_ready(req_ready),
        .resp_rdata(resp_rdata),
        .resp_err(resp_err),
        .resp_valid(resp_valid),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .pstrb(pstrb),
        .pready(pready),
        .prdata(prdata),
        .pslverr(pslverr)
    );

    // Instantiate Slave
    apb_slave u_slave (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .pstrb(pstrb),
        .pready(pready),
        .prdata(prdata),
        .pslverr(pslverr)
    );

    // Clock Generation (100MHz)
    always #5 pclk = ~pclk;

    // Helper Task: Execute Master Transaction
    task cpu_exec(
        input        is_write,
        input [31:0] addr,
        input [31:0] wdata,
        input [3:0]  strb,
        output [31:0] rdata,
        output       err
    );
        @(posedge pclk);
        while (!req_ready) @(posedge pclk);

        req_valid = 1'b1;
        req_write = is_write;
        req_addr  = addr;
        req_wdata = wdata;
        req_strb  = strb;

        @(posedge pclk);
        req_valid = 1'b0;

        while (!resp_valid) @(posedge pclk);
        rdata = resp_rdata;
        err   = resp_err;
    endtask

    logic [31:0] read_val;
    logic        err_out;

    initial begin
        pclk      = 0;
        presetn   = 0;
        req_valid = 0;
        req_write = 0;
        req_addr  = 0;
        req_wdata = 0;
        req_strb  = 4'hF;

        #20;
        presetn = 1;
        #20;

        $display("=================================================");
        $display("       STARTING APB4 PROTOCOL VERIFICATION       ");
        $display("=================================================");

        $display("\n>>> TEST 1: Read Default Reset Values");
        cpu_exec(1'b0, 32'h04, 32'h0, 4'hF, read_val, err_out);
        if (read_val !== 32'h1234_5678 || err_out !== 1'b0) begin
            $display("FAILED: Expected REG1 = 0x12345678, got 0x%08x", read_val);
            $fatal(1);
        end
        $display("PASSED: Default REG1 value verified (0x12345678)");

        $display("\n>>> TEST 2: Full 32-bit Write and Read back on REG0 (0x00)");
        cpu_exec(1'b1, 32'h00, 32'hCAFE_BABE, 4'hF, read_val, err_out);
        if (err_out) begin
            $display("FAILED: Unexpected error on writing REG0");
            $fatal(1);
        end
        cpu_exec(1'b0, 32'h00, 32'h0, 4'hF, read_val, err_out);
        if (read_val !== 32'hCAFE_BABE) begin
            $display("FAILED: Expected 0xCAFEBABE, got 0x%08x", read_val);
            $fatal(1);
        end
        $display("PASSED: REG0 write and read back successful (0xCAFEBABE)");

        $display("\n>>> TEST 3: Byte Strobe Masking (Write only byte 1 [15:8])");
        // Initial value is 0xCAFEBABE. Now write byte 1 with 0x55 -> expect 0xCAFE55BE
        cpu_exec(1'b1, 32'h00, 32'h0000_5500, 4'b0010, read_val, err_out);
        cpu_exec(1'b0, 32'h00, 32'h0, 4'hF, read_val, err_out);
        if (read_val !== 32'hCAFE_55BE) begin
            $display("FAILED: Byte strobe test expected 0xCAFE55BE, got 0x%08x", read_val);
            $fatal(1);
        end
        $display("PASSED: Byte strobe update verified (0xCAFE55BE)");

        $display("\n>>> TEST 4: Read-Only Violation on REG2 (Status Register at 0x08)");
        cpu_exec(1'b1, 32'h08, 32'hFFFF_FFFF, 4'hF, read_val, err_out);
        if (!err_out) begin
            $display("FAILED: Expected PSLVERR when writing to Read-Only register 0x08");
            $fatal(1);
        end
        $display("PASSED: Read-only protection asserted PSLVERR");

        $display("\n>>> TEST 5: Unaligned Address Error Check (0x02)");
        cpu_exec(1'b0, 32'h02, 32'h0, 4'hF, read_val, err_out);
        if (!err_out) begin
            $display("FAILED: Expected PSLVERR on unaligned address access 0x02");
            $fatal(1);
        end
        $display("PASSED: Unaligned address error asserted PSLVERR");

        $display("\n=================================================");
        $display("   ALL APB4 SYSTEMVERILOG TESTS PASSED 100%%!     ");
        $display("=================================================\n");
        $finish;
    end

endmodule
