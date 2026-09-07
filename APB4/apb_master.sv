// ==============================================================================
// Module: apb_master.sv
// Protocol: AMBA APB4 Master FSM (Fully Parameterized with ARM TrustZone PPROT)
// Function: Converts high-level CPU/Host commands into APB4 bus cycles.
// ==============================================================================

`timescale 1ns/1ps

module apb_master #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8
)(
    input  logic                  pclk,
    input  logic                  presetn,

    // High-Level User / CPU Interface
    input  logic                  req_valid,
    input  logic                  req_write,
    input  logic [ADDR_WIDTH-1:0] req_addr,
    input  logic [DATA_WIDTH-1:0] req_wdata,
    input  logic [STRB_WIDTH-1:0] req_strb,
    input  logic [2:0]            req_prot,   // PPROT[2:0]: [0]=Privileged, [1]=Non-Secure, [2]=Instruction
    output logic                  req_ready,
    output logic [DATA_WIDTH-1:0] resp_rdata,
    output logic                  resp_err,
    output logic                  resp_valid,

    // APB4 Bus Interface
    output logic [ADDR_WIDTH-1:0] paddr,
    output logic [2:0]            pprot,
    output logic                  psel,
    output logic                  penable,
    output logic                  pwrite,
    output logic [DATA_WIDTH-1:0] pwdata,
    output logic [STRB_WIDTH-1:0] pstrb,
    input  logic                  pready,
    input  logic [DATA_WIDTH-1:0] prdata,
    input  logic                  pslverr
);

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } state_t;

    state_t state_reg;

    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [STRB_WIDTH-1:0] strb_reg;
    logic [2:0]            prot_reg;
    logic                  write_reg;

    assign paddr   = addr_reg;
    assign pwdata  = wdata_reg;
    assign pstrb   = strb_reg;
    assign pprot   = prot_reg;
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
            prot_reg   <= 3'b000;
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
                        prot_reg  <= req_prot;
                        write_reg <= req_write;
                        state_reg <= SETUP;
                    end
                end

                SETUP: begin
                    // Move unconditionally to ACCESS in the next clock cycle
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
