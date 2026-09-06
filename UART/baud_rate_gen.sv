module baud_rate_gen #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic clk,
    input  logic rst,
    input  logic [15:0] divisor,
    output logic tick
);

    localparam int CALC_DIVISOR = (CLK_FREQ / (BAUD_RATE * 16));
    logic [15:0] d_reg;
    assign d_reg = (divisor != 16'd0) ? divisor : 
                   (CALC_DIVISOR > 0) ? 16'(CALC_DIVISOR) : 16'd1;

    logic [15:0] count_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count_reg <= 0;
            tick <= 0;
        end
        else begin
            if (count_reg == d_reg - 1) begin
                count_reg <= 0;
                tick <= 1'b1;
            end
            else begin
                count_reg <= count_reg + 1;
                tick <= 1'b0;
            end
        end
    end

endmodule
