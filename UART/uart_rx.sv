module uart_rx (
    input  logic clk,
    input  logic rst,
    input  logic rx,
    input  logic s_tick,     
    output logic [7:0] rx_data,
    output logic rx_done
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
            tick_count <= 0;
            bit_index  <= 0;
            rx_done    <= 0;
            rx_data    <= 0;
        end
        else begin
            case (state)

                IDLE: begin
                    rx_done <= 0;
                    if (rx == 0) begin
                        tick_count <= 0;
                        state <= START;
                    end
                end

                START: begin
                    if (s_tick) begin
                        if (tick_count == 7) begin 
                            if (rx == 0) begin
                                tick_count <= 0;
                                state <= DATA;
                            end
                            else
                                state <= IDLE; 
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                DATA: begin
                    if (s_tick) begin
                        if (tick_count == 15) begin 
                            tick_count <= 0;
                            data_reg[bit_index] <= rx;
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
                    if (s_tick) begin
                        if (tick_count == 15) begin 
                            rx_data <= data_reg;
                            rx_done <= 1;
                            state <= IDLE;
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule