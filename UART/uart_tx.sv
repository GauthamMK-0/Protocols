module uart_tx (
    input  logic clk,
    input  logic rst,
    input  logic tx_start,
    input  logic s_tick,     
    input  logic [7:0] tx_data,
    output logic tx,
    output logic tx_busy
);

    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state;

    logic [3:0]  tick_count;
    logic [2:0]  bit_index;
    logic [7:0]  data_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            tx         <= 1'b1;
            tick_count <= 0;
            bit_index  <= 0;
            tx_busy    <= 0;
        end
        else begin
            case (state)

                IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 0;
                    if (tx_start) begin
                        tx_busy   <= 1;
                        data_reg  <= tx_data;
                        tick_count <= 0;
                        state     <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;
                    if (s_tick) begin
                        if (tick_count == 15) begin
                            tick_count <= 0;
                            state     <= DATA;
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                DATA: begin
                    tx <= data_reg[bit_index];
                    if (s_tick) begin
                        if (tick_count == 15) begin
                            tick_count <= 0;
                            if (bit_index < 7)
                                bit_index <= bit_index + 1;
                            else begin
                                bit_index <= 0;
                                state <= STOP;
                            end
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (s_tick) begin
                        if (tick_count == 15) begin
                            state <= IDLE;
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

            endcase
        end
    end

endmodule