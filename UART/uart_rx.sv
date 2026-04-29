module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic clk,
    input  logic rst,
    input  logic rx,
    output logic [7:0] rx_data,
    output logic rx_done
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state;

    logic [15:0] clk_count;
    logic [2:0]  bit_index;
    logic [7:0]  data_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            rx_done   <= 0;
        end
        else begin
            case (state)

                IDLE: begin
                    rx_done <= 0;
                    if (rx == 0) begin
                        clk_count <= 0;
                        state <= START;
                    end
                end

                START: begin
                    if (clk_count == CLKS_PER_BIT/2) begin
                        if (rx == 0) begin
                            clk_count <= 0;
                            state <= DATA;
                        end
                        else
                            state <= IDLE;
                    end
                    else
                        clk_count <= clk_count + 1;
                end

                DATA: begin
                    if (clk_count < CLKS_PER_BIT-1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        data_reg[bit_index] <= rx;
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 0;
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_count < CLKS_PER_BIT-1)
                        clk_count <= clk_count + 1;
                    else begin
                        rx_data <= data_reg;
                        rx_done <= 1;
                        state <= IDLE;
                    end
                end

            endcase
        end
    end

endmodule