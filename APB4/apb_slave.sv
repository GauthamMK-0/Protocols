// ==============================================================================
// Module: apb_slave.sv
// Protocol: AMBA APB4 Slave Peripheral
// ==============================================================================

`timescale 1ns/1ps

module apb_slave (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    input  logic [3:0]  pstrb,
    output logic        pready,
    output logic [31:0] prdata,
    output logic        pslverr
);

    // 4 Internal 32-bit Registers:
    // 0x00: REG0 (RW) - General control
    // 0x04: REG1 (RW) - Parameter register
    // 0x08: REG2 (RO) - Hardware status register (Read-Only)
    // 0x0C: REG3 (RW) - Batch / length register
    logic [31:0] reg0;
    logic [31:0] reg1;
    logic [31:0] reg2; // Status
    logic [31:0] reg3;

    logic addr_err;
    logic ro_err;

    // Address error if unaligned (not a multiple of 4) or out of range (> 0x0C)
    assign addr_err = (paddr[1:0] != 2'b00) || (paddr > 32'h0000_000C);
    // Read-only violation if writing to REG2 (0x08)
    assign ro_err   = pwrite && (paddr == 32'h0000_0008);

    // Combinational Output Multiplexer & Ready/Error Generation
    always_comb begin
        pready  = 1'b0;
        pslverr = 1'b0;
        prdata  = 32'h0;

        if (psel && penable) begin
            pready  = 1'b1;
            pslverr = addr_err || ro_err;

            if (!pwrite && !addr_err) begin
                case (paddr[3:0])
                    4'h0: prdata = reg0;
                    4'h4: prdata = reg1;
                    4'h8: prdata = reg2;
                    4'hC: prdata = reg3;
                    default: prdata = 32'h0;
                endcase
            end
        end
    end

    // Sequential Register Write Logic with Byte Strobes
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg0 <= 32'h0000_0000;
            reg1 <= 32'h1234_5678;
            reg2 <= 32'h0000_00A5; // Default hardware status flag
            reg3 <= 32'h0000_0040;
        end else if (psel && penable && pwrite && !addr_err && !ro_err) begin
            case (paddr[3:0])
                4'h0: begin
                    if (pstrb[0]) reg0[7:0]   <= pwdata[7:0];
                    if (pstrb[1]) reg0[15:8]  <= pwdata[15:8];
                    if (pstrb[2]) reg0[23:16] <= pwdata[23:16];
                    if (pstrb[3]) reg0[31:24] <= pwdata[31:24];
                end
                4'h4: begin
                    if (pstrb[0]) reg1[7:0]   <= pwdata[7:0];
                    if (pstrb[1]) reg1[15:8]  <= pwdata[15:8];
                    if (pstrb[2]) reg1[23:16] <= pwdata[23:16];
                    if (pstrb[3]) reg1[31:24] <= pwdata[31:24];
                end
                4'hC: begin
                    if (pstrb[0]) reg3[7:0]   <= pwdata[7:0];
                    if (pstrb[1]) reg3[15:8]  <= pwdata[15:8];
                    if (pstrb[2]) reg3[23:16] <= pwdata[23:16];
                    if (pstrb[3]) reg3[31:24] <= pwdata[31:24];
                end
                default: ;
            endcase
        end
    end

endmodule
