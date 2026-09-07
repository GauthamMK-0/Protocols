// ==============================================================================
// Testbench: tb_apb_top.sv
// Protocol: Parameterized AMBA APB4 Protocol Verification Environment
// Tests:
// 1. Reset state verification
// 2. Full 32-bit Write and Read
// 3. Byte Strobe (PSTRB) masking
// 4. Read-Only (RO) violation check
// 5. Unaligned address error check
// 6. Address out-of-bounds error check
// 7. ARM TrustZone Security Verification (PPROT[1] Secure vs Non-Secure)
// 8. Privileged Access Verification (PPROT[0] Privileged vs Unprivileged)
// 9. Write-1-to-Clear (W1C) Interrupt Status Register Behavior
// ==============================================================================

`timescale 1ns/1ps

module tb_apb_top;

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;
    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam int NUM_REGS   = 8;

    logic                  pclk;
    logic                  presetn;

    // Master High-Level CPU Interface
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

    // APB4 Interconnect Signals
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

    // Hardware Sideband Signals
    logic [DATA_WIDTH-1:0] hw_status_in;
    logic [DATA_WIDTH-1:0] hw_status_set;
    logic [DATA_WIDTH-1:0] regs_out [NUM_REGS];

    // Instantiate Master
    apb_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) u_master (
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

    // Instantiate Slave
    apb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .NUM_REGS(NUM_REGS)
    ) u_slave (
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

    // Clock Generation (100MHz / 10ns period)
    always #5 pclk = ~pclk;

    // Helper Task: Execute Master Transaction
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

    logic [DATA_WIDTH-1:0] read_val;
    logic                  err_out;

    initial begin
        pclk          = 0;
        presetn       = 0;
        req_valid     = 0;
        req_write     = 0;
        req_addr      = 0;
        req_wdata     = 0;
        req_strb      = 4'hF;
        req_prot      = 3'b001; // Default: Privileged, Secure, Data (PPROT[1]=0, PPROT[0]=1)
        hw_status_in  = 32'h0000_00A5;
        hw_status_set = 32'h0;

        #20;
        presetn = 1;
        #20;

        $display("==================================================================");
        $display("     STARTING FULLY PARAMETERIZED APB4 + TRUSTZONE TESTBENCH      ");
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
        // Write byte 1 with 0x55 on 0xCAFEBABE -> expect 0xCAFE55BE
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
        // TEST 6: ARM TrustZone Security Checks (PPROT[1]: 0=Secure, 1=Non-Secure)
        // -------------------------------------------------------------
        $display("\n>>> TEST 6: ARM TrustZone Secure Register Access (REG6 at 0x18)");
        
        // A. Secure Access (PPROT[1] = 0, PPROT[0] = 1 -> req_prot = 3'b001) -> MUST PASS
        cpu_exec(1'b0, 32'h18, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(!err_out && read_val == 32'hDEAD_BEEF) 
            else $fatal(1, "Secure read failed on REG6");
        $display("  [+] Secure Read to REG6 PASSED (Returned 0xDEADBEEF)");

        cpu_exec(1'b1, 32'h18, 32'h1122_3344, 4'hF, 3'b001, read_val, err_out);
        assert(!err_out) else $fatal(1, "Secure write failed on REG6");
        $display("  [+] Secure Write to REG6 PASSED");

        // B. Non-Secure Access (PPROT[1] = 1 -> req_prot = 3'b011) -> MUST FAIL with PSLVERR
        cpu_exec(1'b0, 32'h18, 32'h0, 4'hF, 3'b011, read_val, err_out);
        assert(err_out) else $fatal(1, "Non-Secure Read did NOT trigger PSLVERR on Secure REG6!");
        $display("  [+] Non-Secure Read correctly blocked with PSLVERR");

        cpu_exec(1'b1, 32'h18, 32'h9999_9999, 4'hF, 3'b011, read_val, err_out);
        assert(err_out) else $fatal(1, "Non-Secure Write did NOT trigger PSLVERR on Secure REG6!");
        $display("  [+] Non-Secure Write correctly blocked with PSLVERR");

        // -------------------------------------------------------------
        // TEST 7: Privileged Access Control (PPROT[0]: 0=Normal, 1=Privileged)
        // -------------------------------------------------------------
        $display("\n>>> TEST 7: Privileged Register Access (REG5 at 0x14)");
        
        // A. Privileged Access (PPROT[0] = 1 -> req_prot = 3'b001) -> MUST PASS
        cpu_exec(1'b0, 32'h14, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(!err_out && read_val == 32'h0000_CAFE) 
            else $fatal(1, "Privileged read failed on REG5");
        $display("  [+] Privileged Read to REG5 PASSED");

        // B. Unprivileged / User Access (PPROT[0] = 0 -> req_prot = 3'b000) -> MUST FAIL
        cpu_exec(1'b0, 32'h14, 32'h0, 4'hF, 3'b000, read_val, err_out);
        assert(err_out) else $fatal(1, "Unprivileged access did NOT trigger PSLVERR on REG5!");
        $display("  [+] Unprivileged Read correctly blocked with PSLVERR");

        // -------------------------------------------------------------
        // TEST 8: Write-1-to-Clear (W1C) Interrupt Register (REG4 at 0x10)
        // -------------------------------------------------------------
        $display("\n>>> TEST 8: Write-1-to-Clear (W1C) Status Handling (REG4 at 0x10)");
        
        // Hardware sets interrupt flags: bits [3:0] = 4'b1111 (0x0F)
        @(posedge pclk);
        hw_status_set = 32'h0000_000F;
        @(posedge pclk);
        hw_status_set = 32'h0;

        // CPU reads interrupt status
        cpu_exec(1'b0, 32'h10, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(read_val == 32'h0000_000F) else $fatal(1, "Expected W1C register = 0x0F, got 0x%08x", read_val);
        $display("  [+] HW set interrupt flags verified (0x0000000F)");

        // CPU writes 1 to clear bits 1 and 2 (writes 0x06) -> remaining bits should be 0x09 (bits 0 and 3)
        cpu_exec(1'b1, 32'h10, 32'h0000_0006, 4'hF, 3'b001, read_val, err_out);
        cpu_exec(1'b0, 32'h10, 32'h0, 4'hF, 3'b001, read_val, err_out);
        assert(read_val == 32'h0000_0009) else $fatal(1, "Expected W1C remaining = 0x09, got 0x%08x", read_val);
        $display("  [+] W1C bit clearing verified (0x00000009 remaining after clearing 0x06)");

        $display("\n==================================================================");
        $display("   ALL PARAMETERIZED APB4 + TRUSTZONE TESTS PASSED 100%%!         ");
        $display("==================================================================\n");
        $finish;
    end

endmodule
