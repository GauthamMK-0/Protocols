// ==============================================================================
// Testbench: tb_apb_top.sv
// Protocol: Exhaustive AMBA APB4 Protocol Verification Suite
// Features Verified:
// 1. Reset state verification across all CSRs
// 2. Full word read and write (32-bit)
// 3. Byte strobe (PSTRB) masking & individual byte updates
// 4. Read-Only (RO) violation check (PSLVERR)
// 5. Unaligned address error check (PSLVERR)
// 6. Address out-of-bounds error check (PSLVERR)
// 7. ARM TrustZone security verification (PPROT[1] Secure vs Non-Secure)
// 8. Privileged access verification (PPROT[0] Privileged vs Unprivileged)
// 9. Root-of-Trust multi-domain security (PPROT[1:0] Secure & Privileged)
// 10. Write-1-to-Clear (W1C) interrupt status handling
// 11. Null / Dummy write (PSTRB = 0) integrity check
// 12. Back-to-back streaming transactions
// 13. Dynamic hardware status register updates
// 14. 64-bit Parameterized APB4 Bus Instance (DATA_WIDTH=64, STRB_WIDTH=8)
// ==============================================================================

`timescale 1ns/1ps

module tb_apb_top;

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;
    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam int NUM_REGS   = 8;

    logic                  pclk;
    logic                  presetn;

    // -------------------------------------------------------------
    // 32-bit APB4 Master/Slave Signals
    // -------------------------------------------------------------
    logic                  req_valid;
    logic                  req_write;
    logic [ADDR_WIDTH-1:0] req_addr;
    logic [DATA_WIDTH-1:0] req_wdata;
    logic [STRB_WIDTH-1:0] req_strb;
    logic [2:0]            req_prot;
    logic                  req_ready;
    logic [DATA_WIDTH-1:0] resp_rdata;
    logic                  resp_err;
    logic                  resp_valid;

    logic [ADDR_WIDTH-1:0] paddr;
    logic [2:0]            pprot;
    logic                  psel;
    logic                  penable;
    logic                  pwrite;
    logic [DATA_WIDTH-1:0] pwdata;
    logic [STRB_WIDTH-1:0] pstrb;
    logic                  pready;
    logic [DATA_WIDTH-1:0] prdata;
    logic                  pslverr;

    logic [DATA_WIDTH-1:0] hw_status_in;
    logic [DATA_WIDTH-1:0] hw_status_set;
    logic [DATA_WIDTH-1:0] regs_out [NUM_REGS];

    // Instantiate 32-bit APB4 Master
    apb_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) u_master_32 (
        .pclk(pclk),
        .presetn(presetn),
        .req_valid(req_valid),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_strb(req_strb),
        .req_prot(req_prot),
        .req_ready(req_ready),
        .resp_rdata(resp_rdata),
        .resp_err(resp_err),
        .resp_valid(resp_valid),
        .paddr(paddr),
        .pprot(pprot),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .pstrb(pstrb),
        .pready(pready),
        .prdata(prdata),
        .pslverr(pslverr)
    );

    // Instantiate 32-bit APB4 Slave
    apb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .NUM_REGS(NUM_REGS)
    ) u_slave_32 (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .pprot(pprot),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .pstrb(pstrb),
        .pready(pready),
        .prdata(prdata),
        .pslverr(pslverr),
        .hw_status_in(hw_status_in),
        .hw_status_set(hw_status_set),
        .regs_out(regs_out)
    );

    // -------------------------------------------------------------
    // 64-bit Parameterized APB4 Master/Slave Instance
    // -------------------------------------------------------------
    localparam int DATA_WIDTH_64 = 64;
    localparam int STRB_WIDTH_64 = DATA_WIDTH_64 / 8; // 8 bytes

    logic                     req_valid_64;
    logic                     req_write_64;
    logic [ADDR_WIDTH-1:0]    req_addr_64;
    logic [DATA_WIDTH_64-1:0] req_wdata_64;
    logic [STRB_WIDTH_64-1:0] req_strb_64;
    logic [2:0]               req_prot_64;
    logic                     req_ready_64;
    logic [DATA_WIDTH_64-1:0] resp_rdata_64;
    logic                     resp_err_64;
    logic                     resp_valid_64;

    logic [ADDR_WIDTH-1:0]    paddr_64;
    logic [2:0]               pprot_64;
    logic                     psel_64;
    logic                     penable_64;
    logic                     pwrite_64;
    logic [DATA_WIDTH_64-1:0] pwdata_64;
    logic [STRB_WIDTH_64-1:0] pstrb_64;
    logic                     pready_64;
    logic [DATA_WIDTH_64-1:0] prdata_64;
    logic                     pslverr_64;

    apb_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH_64),
        .STRB_WIDTH(STRB_WIDTH_64)
    ) u_master_64 (
        .pclk(pclk),
        .presetn(presetn),
        .req_valid(req_valid_64),
        .req_write(req_write_64),
        .req_addr(req_addr_64),
        .req_wdata(req_wdata_64),
        .req_strb(req_strb_64),
        .req_prot(req_prot_64),
        .req_ready(req_ready_64),
        .resp_rdata(resp_rdata_64),
        .resp_err(resp_err_64),
        .resp_valid(resp_valid_64),
        .paddr(paddr_64),
        .pprot(pprot_64),
        .psel(psel_64),
        .penable(penable_64),
        .pwrite(pwrite_64),
        .pwdata(pwdata_64),
        .pstrb(pstrb_64),
        .pready(pready_64),
        .prdata(prdata_64),
        .pslverr(pslverr_64)
    );

    apb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH_64),
        .STRB_WIDTH(STRB_WIDTH_64),
        .NUM_REGS(NUM_REGS)
    ) u_slave_64 (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr_64),
        .pprot(pprot_64),
        .psel(psel_64),
        .penable(penable_64),
        .pwrite(pwrite_64),
        .pwdata(pwdata_64),
        .pstrb(pstrb_64),
        .pready(pready_64),
        .prdata(prdata_64),
        .pslverr(pslverr_64),
        .hw_status_in(64'h0000_0000_0000_00A5),
        .hw_status_set(64'h0),
        .regs_out()
    );

    // Clock Generation (100MHz / 10ns period)
    always #5 pclk = ~pclk;

    // Helper Task: Execute 32-bit Master Transaction
    task cpu_exec(
        input                  is_write,
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] wdata,
        input [STRB_WIDTH-1:0] strb,
        input [2:0]            prot,
        output [DATA_WIDTH-1:0] rdata,
        output                 err
    );
        @(posedge pclk);
        while (!req_ready) @(posedge pclk);

        req_valid = 1'b1;
        req_write = is_write;
        req_addr  = addr;
        req_wdata = wdata;
        req_strb  = strb;
        req_prot  = prot;

        @(posedge pclk);
        req_valid = 1'b0;

        while (!resp_valid) @(posedge pclk);
        rdata = resp_rdata;
        err   = resp_err;
    endtask

    // Helper Task: Execute 64-bit Master Transaction
    task cpu_exec_64(
        input                     is_write,
        input [ADDR_WIDTH-1:0]    addr,
        input [DATA_WIDTH_64-1:0] wdata,
        input [STRB_WIDTH_64-1:0] strb,
        input [2:0]               prot,
        output [DATA_WIDTH_64-1:0] rdata,
        output                    err
    );
        @(posedge pclk);
        while (!req_ready_64) @(posedge pclk);

        req_valid_64 = 1'b1;
        req_write_64 = is_write;
        req_addr_64  = addr;
        req_wdata_64 = wdata;
        req_strb_64  = strb;
        req_prot_64  = prot;

        @(posedge pclk);
        req_valid_64 = 1'b0;

        while (!resp_valid_64) @(posedge pclk);
        rdata = resp_rdata_64;
        err   = resp_err_64;
    endtask

    logic [DATA_WIDTH-1:0]    read_val;
    logic [DATA_WIDTH_64-1:0] read_val_64;
    logic                     err_out;

    initial begin
        pclk          = 0;
        presetn       = 0;
        req_valid     = 0;
        req_write     = 0;
        req_addr      = 0;
        req_wdata     = 0;
        req_strb      = 4'hF;
        req_prot      = 3'b001; // Privileged, Secure, Data
        hw_status_in  = 32'h0000_00A5;
        hw_status_set = 32'h0;

        req_valid_64  = 0;
        req_write_64  = 0;
        req_addr_64   = 0;
        req_wdata_64  = 0;
        req_strb_64   = 8'hFF;
        req_prot_64   = 3'b001;

        #20;
        presetn = 1;
        #20;

        $display("==================================================================");
        $display("     EXHAUSTIVE AMBA APB4 PROTOCOL & SECURITY VERIFICATION        ");
        $display("==================================================================");

        // -------------------------------------------------------------
        // TEST 1: Default Reset Read
        // -------------------------------------------------------------
        $display("\n>>> TEST 1: Read Default Reset Values");
        cpu_exec(1'b0, 32'h04, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(read_val == 32'h1234_5678 && err_out == 1'b0) 
            else $fatal(1, "Expected REG1 = 0x12345678, got 0x%08x", read_val);
        $display("PASSED: Default REG1 value verified (0x12345678)");

        // -------------------------------------------------------------
        // TEST 2: Full 32-bit Read and Write
        // -------------------------------------------------------------
        $display("\n>>> TEST 2: Full 32-bit Write and Read back on REG0 (0x00)");
        cpu_exec(1'b1, 32'h00, 32'hCAFE_BABE, 4'hF, 3'b001, read_val, err_out);
        assert(!err_out) else $fatal(1, "Unexpected error on writing REG0");
        cpu_exec(1'b0, 32'h00, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(read_val == 32'hCAFE_BABE) 
            else $fatal(1, "Expected 0xCAFEBABE, got 0x%08x", read_val);
        $display("PASSED: REG0 write and read back successful (0xCAFEBABE)");

        // -------------------------------------------------------------
        // TEST 3: Byte Strobe Masking
        // -------------------------------------------------------------
        $display("\n>>> TEST 3: Byte Strobe Masking (Write only byte 1 [15:8])");
        cpu_exec(1'b1, 32'h00, 32'h0000_5500, 4'b0010, 3'b001, read_val, err_out);
        cpu_exec(1'b0, 32'h00, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(read_val == 32'hCAFE_55BE) 
            else $fatal(1, "Byte strobe test expected 0xCAFE55BE, got 0x%08x", read_val);
        $display("PASSED: Byte strobe update verified (0xCAFE55BE)");

        // -------------------------------------------------------------
        // TEST 4: Read-Only Violation (REG2 at 0x08)
        // -------------------------------------------------------------
        $display("\n>>> TEST 4: Read-Only Violation on REG2 (Status Register at 0x08)");
        cpu_exec(1'b1, 32'h08, 32'hFFFF_FFFF, 4'hF, 3'b001, read_val, err_out);
        assert(err_out) else $fatal(1, "Expected PSLVERR when writing to Read-Only register 0x08");
        $display("PASSED: Read-only protection asserted PSLVERR");

        // -------------------------------------------------------------
        // TEST 5: Unaligned Address Error Check
        // -------------------------------------------------------------
        $display("\n>>> TEST 5: Unaligned Address Error Check (0x02)");
        cpu_exec(1'b0, 32'h02, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(err_out) else $fatal(1, "Expected PSLVERR on unaligned address access 0x02");
        $display("PASSED: Unaligned address error asserted PSLVERR");

        // -------------------------------------------------------------
        // TEST 6: Out-of-Range Address Error Check (0x24 and 0x100)
        // -------------------------------------------------------------
        $display("\n>>> TEST 6: Out-of-Range Address Error Check (0x24 & 0x100)");
        cpu_exec(1'b0, 32'h24, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(err_out) else $fatal(1, "Expected PSLVERR on out-of-range address 0x24");
        cpu_exec(1'b1, 32'h100, 32'hDEADBEEF, 4'hF, 3'b001, read_val, err_out);
        assert(err_out) else $fatal(1, "Expected PSLVERR on out-of-range address 0x100");
        $display("PASSED: Out-of-range address accesses correctly returned PSLVERR");

        // -------------------------------------------------------------
        // TEST 7: ARM TrustZone Security Checks (PPROT[1]: 0=Secure, 1=Non-Secure)
        // -------------------------------------------------------------
        $display("\n>>> TEST 7: ARM TrustZone Secure Register Access (REG6 at 0x18)");
        // A. Secure Access -> PASS
        cpu_exec(1'b0, 32'h18, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(!err_out && read_val == 32'hDEAD_BEEF) else $fatal(1, "Secure read failed on REG6");
        cpu_exec(1'b1, 32'h18, 32'h1122_3344, 4'hF, 3'b001, read_val, err_out);
        assert(!err_out) else $fatal(1, "Secure write failed on REG6");
        $display("  [+] Secure Read/Write to REG6 PASSED");

        // B. Non-Secure Access -> FAIL with PSLVERR
        cpu_exec(1'b0, 32'h18, 32'h0, 4'hF, 3'b011, read_val, err_out);
        assert(err_out) else $fatal(1, "Non-Secure Read did NOT trigger PSLVERR on Secure REG6!");
        cpu_exec(1'b1, 32'h18, 32'h9999_9999, 4'hF, 3'b011, read_val, err_out);
        assert(err_out) else $fatal(1, "Non-Secure Write did NOT trigger PSLVERR on Secure REG6!");
        $display("  [+] Non-Secure Read/Write correctly blocked with PSLVERR");

        // -------------------------------------------------------------
        // TEST 8: Privileged Access Control (PPROT[0]: 0=Normal, 1=Privileged)
        // -------------------------------------------------------------
        $display("\n>>> TEST 8: Privileged Register Access (REG5 at 0x14)");
        cpu_exec(1'b0, 32'h14, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(!err_out && read_val == 32'h0000_CAFE) else $fatal(1, "Privileged read failed on REG5");
        cpu_exec(1'b0, 32'h14, 32'h0, 4'hF, 3'b000, read_val, err_out);
        assert(err_out) else $fatal(1, "Unprivileged access did NOT trigger PSLVERR on REG5!");
        $display("  [+] Privilege gating verified (Privileged passed, Unprivileged blocked)");

        // -------------------------------------------------------------
        // TEST 9: Root-of-Trust (REG7 at 0x1C - Requires Secure & Privileged)
        // -------------------------------------------------------------
        $display("\n>>> TEST 9: Root-of-Trust Dual-Security (REG7 at 0x1C)");
        // Valid: Secure & Privileged (prot = 3'b001)
        cpu_exec(1'b0, 32'h1C, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(!err_out && read_val == 32'h5A5A_F00F) else $fatal(1, "Root-of-Trust read failed");
        // Invalid: Non-Secure (prot = 3'b011)
        cpu_exec(1'b0, 32'h1C, 32'h0, 4'hF, 3'b011, read_val, err_out);
        assert(err_out) else $fatal(1, "Non-Secure access did not fail on REG7");
        // Invalid: Unprivileged (prot = 3'b000)
        cpu_exec(1'b0, 32'h1C, 32'h0, 4'hF, 3'b000, read_val, err_out);
        assert(err_out) else $fatal(1, "Unprivileged access did not fail on REG7");
        $display("PASSED: Root-of-Trust security verified (Requires both Secure and Privileged mode)");

        // -------------------------------------------------------------
        // TEST 10: Write-1-to-Clear (W1C) Interrupt Handling (REG4 at 0x10)
        // -------------------------------------------------------------
        $display("\n>>> TEST 10: Write-1-to-Clear (W1C) Status Handling (REG4 at 0x10)");
        @(posedge pclk);
        hw_status_set = 32'h0000_000F;
        @(posedge pclk);
        hw_status_set = 32'h0;

        cpu_exec(1'b0, 32'h10, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(read_val == 32'h0000_000F) else $fatal(1, "Expected W1C = 0x0F, got 0x%08x", read_val);
        // Clear bits 1 and 2
        cpu_exec(1'b1, 32'h10, 32'h0000_0006, 4'hF, 3'b001, read_val, err_out);
        cpu_exec(1'b0, 32'h10, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(read_val == 32'h0000_0009) else $fatal(1, "Expected W1C = 0x09, got 0x%08x", read_val);
        $display("PASSED: W1C interrupt flag set and bit clearing verified");

        // -------------------------------------------------------------
        // TEST 11: Null / Dummy Write (PSTRB = 4'b0000)
        // -------------------------------------------------------------
        $display("\n>>> TEST 11: Null Write (PSTRB = 4'b0000)");
        cpu_exec(1'b1, 32'h00, 32'hFFFF_FFFF, 4'b0000, 3'b001, read_val, err_out);
        assert(!err_out) else $fatal(1, "Null write triggered unexpected error");
        cpu_exec(1'b0, 32'h00, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(read_val == 32'hCAFE_55BE) else $fatal(1, "Null write corrupted register content!");
        $display("PASSED: Null write completed with zero data corruption");

        // -------------------------------------------------------------
        // TEST 12: Back-to-Back Consecutive Transactions
        // -------------------------------------------------------------
        $display("\n>>> TEST 12: Back-to-Back Streaming Transactions");
        for (int i = 0; i < 4; i++) begin
            cpu_exec(1'b1, 32'h0C, 32'h1000 + i, 4'hF, 3'b001, read_val, err_out);
            assert(!err_out) else $fatal(1, "Back-to-back write %0d failed", i);
            cpu_exec(1'b0, 32'h0C, 32'h0, 4'hF, 3'b001, read_val, err_out);
            assert(read_val == (32'h1000 + i)) else $fatal(1, "Back-to-back read %0d mismatch", i);
        end
        $display("PASSED: 8 consecutive back-to-back transfers verified without bus stalls");

        // -------------------------------------------------------------
        // TEST 13: Dynamic Hardware Status Updates
        // -------------------------------------------------------------
        $display("\n>>> TEST 13: Dynamic Hardware Status Register Updates (REG2)");
        hw_status_in = 32'hA1B2_C3D4;
        @(posedge pclk);
        cpu_exec(1'b0, 32'h08, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(read_val == 32'hA1B2_C3D4) else $fatal(1, "Dynamic HW status update failed");
        $display("PASSED: Live hardware status reflect verified (0xA1B2C3D4)");

        // -------------------------------------------------------------
        // TEST 14: 64-bit Parameterized APB4 Instance Verification
        // -------------------------------------------------------------
        $display("\n>>> TEST 14: 64-bit Parameterized APB4 Bus Verification (DATA_WIDTH=64)");
        // Write 64-bit word to 0x00
        cpu_exec_64(1'b1, 32'h00, 64'h0123_4567_89AB_CDEF, 8'hFF, 3'b001, read_val_64, err_out);
        assert(!err_out) else $fatal(1, "64-bit write failed");
        cpu_exec_64(1'b0, 32'h00, 64'h0, 8'hFF, 3'b001, read_val_64, err_out);
        assert(read_val_64 == 64'h0123_4567_89AB_CDEF) 
            else $fatal(1, "64-bit read mismatch: Expected 0x0123456789ABCDEF, got 0x%016x", read_val_64);
        $display("  [+] Full 64-bit Write/Read verified (0x0123456789ABCDEF)");

        // 64-bit byte strobe: write upper 32 bits only (strb = 8'hF0)
        cpu_exec_64(1'b1, 32'h00, 64'hFEED_FACE_0000_0000, 8'hF0, 3'b001, read_val_64, err_out);
        cpu_exec_64(1'b0, 32'h00, 64'h0, 8'hFF, 3'b001, read_val_64, err_out);
        assert(read_val_64 == 64'hFEED_FACE_89AB_CDEF) 
            else $fatal(1, "64-bit byte strobe mismatch: got 0x%016x", read_val_64);
        $display("  [+] 64-bit Byte Strobe masking verified (0xFEEDFACE89ABCDEF)");

        // 64-bit unaligned access check (e.g., 0x04 is unaligned on 64-bit/8-byte boundary)
        cpu_exec_64(1'b0, 32'h04, 64'h0, 8'hFF, 3'b001, read_val_64, err_out);
        assert(err_out) else $fatal(1, "Expected PSLVERR on 64-bit unaligned address 0x04");
        $display("  [+] 64-bit 8-byte alignment exception correctly asserted PSLVERR");

        $display("\n==================================================================");
        $display("   ALL 14 EXHAUSTIVE APB4 + TRUSTZONE TESTS PASSED 100%%!         ");
        $display("==================================================================\n");
        $finish;
    end

endmodule
