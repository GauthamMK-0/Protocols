module fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16
)(
    input  logic clk,
    input  logic rst,
    input  logic push,
    input  logic pop,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic full,
    output logic empty,
    output logic [$clog2(FIFO_DEPTH):0] count
);

    logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH-1:0];
    logic [$clog2(FIFO_DEPTH)-1:0] wr_ptr;
    logic [$clog2(FIFO_DEPTH)-1:0] rd_ptr;
    logic [$clog2(FIFO_DEPTH):0]   count_reg;

    assign count = count_reg;
    assign full  = (count_reg == FIFO_DEPTH);
    assign empty = (count_reg == 0);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            count_reg <= 0;
        end
        else begin
            case ({push, pop})
                2'b10: begin // Push only
                    if (!full) begin
                        mem[wr_ptr] <= data_in;
                        wr_ptr      <= wr_ptr + 1;
                        count_reg   <= count_reg + 1;
                    end
                end
                2'b01: begin // Pop only
                    if (!empty) begin
                        rd_ptr    <= rd_ptr + 1;
                        count_reg <= count_reg - 1;
                    end
                end
                2'b11: begin // Push and Pop
                    mem[wr_ptr] <= data_in;
                    wr_ptr      <= wr_ptr + 1;
                    rd_ptr      <= rd_ptr + 1;
                end
                default: ; // Do nothing
            endcase
        end
    end

    assign data_out = mem[rd_ptr];

endmodule
