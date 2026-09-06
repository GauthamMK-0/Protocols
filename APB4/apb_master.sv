// ==============================================================================
// Module: apb_master.sv
// Protocol: AMBA APB4 Master FSM
// Function: Converts high-level CPU/Host read & write commands into APB4 bus cycles.
// ==============================================================================

`timescale 1ns/1ps

module apb_master (
    input  logic        pclk,
    input  logic        presetn,

    // High-Level User / CPU Interface
    input  logic        req_valid,
    input  logic        req_write,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_strb,
    output logic        req_ready,
    output logic [31:0] resp_rdata,
    output logic        resp_err,
    output logic        resp_valid,

    // APB4 Bus Interface
    output logic [31:0] paddr,
    output logic        psel,
    output logic        penable,
    output logic        pwrite,
    output logic [31:0] pwdata,
    output logic [3:0]  pstrb,
    input  logic        pready,
    input  logic [31:0] prdata,
    input  logic        pslverr
);

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } state_t;

    state_t state_reg;

    logic [31:0] addr_reg;
    logic [31:0] wdata_reg;
    logic [3:0]  strb_reg;
    logic        write_reg;

    assign paddr   = addr_reg;
    assign pwdata  = wdata_reg;
    assign pstrb   = strb_reg;
    assign pwrite  = write_reg;

    assign psel    = (state_reg == SETUP || state_reg == ACCESS);
    assign penable = (state_reg == ACCESS);
    assign req_ready = (state_reg == IDLE);

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            state_reg  <= IDLE;
            addr_reg   <= '0;
            wdata_reg  <= '0;
            strb_reg   <= '0;
            write_reg  <= 1'b0;
            resp_rdata <= '0;
            resp_err   <= 1'b0;
            resp_valid <= 1'b0;
        end else begin
            resp_valid <= 1'b0;

            case (state_reg)
                IDLE: begin
                    if (req_valid) begin
                        addr_reg  <= req_addr;
                        wdata_reg <= req_wdata;
                        strb_reg  <= req_strb;
                        write_reg <= req_write;
                        state_reg <= SETUP;
                    end
                end

                SETUP: begin
                    // Move unconditionally to ACCESS in next cycle
                    state_reg <= ACCESS;
                end

                ACCESS: begin
                    if (pready) begin
                        resp_rdata <= prdata;
                        resp_err   <= pslverr;
                        resp_valid <= 1'b1;
                        state_reg  <= IDLE;
                    end
                end

                default: state_reg <= IDLE;
            endcase
        end
    end

endmodule
