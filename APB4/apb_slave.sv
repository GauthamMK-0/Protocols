// ==============================================================================
// Module: apb_slave.sv
// Protocol: AMBA APB4 Slave Peripheral (Parameterized with ARM TrustZone PPROT & W1C)
// ==============================================================================

`timescale 1ns/1ps

module apb_slave #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8,
    parameter int NUM_REGS   = 8
)(
    input  logic                  pclk,
    input  logic                  presetn,
    input  logic [ADDR_WIDTH-1:0] paddr,
    input  logic [2:0]            pprot,   // [0]: 0=Normal, 1=Privileged | [1]: 0=Secure, 1=Non-Secure | [2]: 0=Data, 1=Instruction
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [DATA_WIDTH-1:0] pwdata,
    input  logic [STRB_WIDTH-1:0] pstrb,
    output logic                  pready,
    output logic [DATA_WIDTH-1:0] prdata,
    output logic                  pslverr,

    // Hardware Sideband Interface
    input  logic [DATA_WIDTH-1:0] hw_status_in,     // Live hardware update for status register (REG2)
    input  logic [DATA_WIDTH-1:0] hw_status_set,    // Hardware sets interrupt/event flags (REG4 W1C)
    output logic [DATA_WIDTH-1:0] regs_out [NUM_REGS]
);

    // Register Array:
    // Index 0 (0x00): REG0 (RW) - General control
    // Index 1 (0x04): REG1 (RW) - Configuration / Parameters
    // Index 2 (0x08): REG2 (RO) - Hardware live status register (Read-Only)
    // Index 3 (0x0C): REG3 (RW) - Batch / DMA length register
    // Index 4 (0x10): REG4 (W1C) - Interrupt status register (Write-1-to-Clear)
    // Index 5 (0x14): REG5 (PRIVILEGED RW) - Protected SoC config (Requires PPROT[0]=1)
    // Index 6 (0x18): REG6 (SECURE RW) - ARM TrustZone Secure CSR (Requires PPROT[1]=0)
    // Index 7 (0x1C): REG7 (SECURE & PRIVILEGED RW) - Root-of-Trust (Requires PPROT[1]=0 & PPROT[0]=1)
    logic [DATA_WIDTH-1:0] reg_mem [NUM_REGS];

    // Export internal registers to hardware
    assign regs_out = reg_mem;

    localparam int ALIGN_BITS = (STRB_WIDTH > 1) ? $clog2(STRB_WIDTH) : 1;
    localparam int IDX_BITS   = (NUM_REGS > 1) ? $clog2(NUM_REGS) : 1;

    logic [IDX_BITS-1:0] reg_index;
    assign reg_index = paddr[ALIGN_BITS + IDX_BITS - 1 : ALIGN_BITS];

    // 1. Address alignment and aperture error checking
    logic align_err;
    logic range_err;
    logic addr_err;
    assign align_err = (STRB_WIDTH > 1) ? (paddr[ALIGN_BITS-1:0] != '0) : 1'b0;
    assign range_err = (paddr >= (NUM_REGS * STRB_WIDTH));
    assign addr_err  = align_err || range_err;

    // 2. Read-Only violation check (Writing to Index 2)
    logic ro_err;
    assign ro_err = pwrite && (reg_index == 'd2);

    // 3. ARM TrustZone Security check (PPROT[1]: 0=Secure, 1=Non-Secure)
    // Non-Secure masters are blocked from reading or writing Secure registers (Index 6, 7)
    logic sec_err;
    assign sec_err = (pprot[1] == 1'b1) && ((reg_index == 'd6) || (reg_index == 'd7));

    // 4. Privileged Access check (PPROT[0]: 0=Normal/Unprivileged, 1=Privileged)
    // Unprivileged masters are blocked from reading or writing Privileged registers (Index 5, 7)
    logic priv_err;
    assign priv_err = (pprot[0] == 1'b0) && ((reg_index == 'd5) || (reg_index == 'd7));

    // Combined Error Condition
    logic error_comb;
    assign error_comb = addr_err || ro_err || sec_err || priv_err;

    // APB4 Handshake and Response
    assign pready  = psel && penable;
    assign pslverr = (psel && penable) && error_comb;

    // Combinational Read Multiplexer
    always_comb begin
        prdata = '0;
        if (psel && penable && !pwrite && !error_comb) begin
            if (int'(reg_index) < NUM_REGS) begin
                prdata = reg_mem[reg_index];
            end
        end
    end

    // Sequential Register Write Logic with Byte Strobes, W1C, and Security Gating
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_mem[0] <= 'h0000_0000;
            reg_mem[1] <= 'h1234_5678;
            reg_mem[2] <= 'h0000_00A5; // Default hardware status flag
            reg_mem[3] <= 'h0000_0040;
            reg_mem[4] <= 'h0000_0000; // W1C
            if (NUM_REGS > 5) reg_mem[5] <= 'h0000_CAFE; // Privileged
            if (NUM_REGS > 6) reg_mem[6] <= 'hDEAD_BEEF; // TrustZone Secure
            if (NUM_REGS > 7) reg_mem[7] <= 'h5A5A_F00F; // Secure & Privileged
            for (int i = 8; i < NUM_REGS; i++) begin
                reg_mem[i] <= '0;
            end
        end else begin
            // Dynamic hardware status updates
            reg_mem[2] <= hw_status_in;
            reg_mem[4] <= reg_mem[4] | hw_status_set;

            if (psel && penable && pwrite && !error_comb) begin
                if (reg_index == 'd4) begin
                    // Write-1-to-Clear (W1C) logic with byte strobes
                    for (int b = 0; b < STRB_WIDTH; b++) begin
                        if (pstrb[b]) begin
                            reg_mem[4][b*8 +: 8] <= (reg_mem[4][b*8 +: 8] & ~pwdata[b*8 +: 8]) | hw_status_set[b*8 +: 8];
                        end
                    end
                end else if (reg_index != 'd2) begin
                    // Standard Read/Write registers with Byte Strobes
                    for (int b = 0; b < STRB_WIDTH; b++) begin
                        if (pstrb[b]) begin
                            reg_mem[reg_index][b*8 +: 8] <= pwdata[b*8 +: 8];
                        end
                    end
                end
            end
        end
    end

endmodule
