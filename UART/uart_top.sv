module uart_top #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200,
    parameter FIFO_DEPTH = 16
)(
    input  logic clk,
    input  logic rst,
    
    // CPU Interface - Transmitter
    input  logic tx_push,
    input  logic [7:0] tx_din,
    output logic tx_full,
    
    // CPU Interface - Receiver
    input  logic rx_pop,
    output logic [7:0] rx_dout,
    output logic rx_empty,
    output logic [4:0] rx_count, // FIFO count (assuming depth 16)
    
    // Physical Pins
    output logic tx_pin,
    input  logic rx_pin
);

    // Internal Signals
    logic s_tick;
    logic tx_start, tx_busy;
    logic [7:0] tx_data;
    logic rx_done;
    logic [7:0] rx_data;
    
    logic tx_fifo_empty;
    logic tx_fifo_pop;

    // 1. Baud Rate Generator
    baud_rate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) brg_inst (
        .clk(clk),
        .rst(rst),
        .divisor(16'd0),
        .tick(s_tick)
    );

    // 2. Transmitter FIFO
    fifo #(.FIFO_DEPTH(FIFO_DEPTH)) tx_fifo_inst (
        .clk(clk),
        .rst(rst),
        .push(tx_push),
        .pop(tx_fifo_pop),
        .data_in(tx_din),
        .data_out(tx_data),
        .full(tx_full),
        .empty(tx_fifo_empty),
        .count()
    );

    // 3. UART Transmitter
    uart_tx tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .s_tick(s_tick),
        .tx_data(tx_data),
        .tx(tx_pin),
        .tx_busy(tx_busy)
    );

    // Auto-start logic: If FIFO is not empty and TX is not busy, start a new byte
    // We need a small FSM or edge detector to pulse tx_start and tx_fifo_pop
    typedef enum logic {TX_IDLE, TX_START_BYTE} tx_fsm_t;
    tx_fsm_t tx_fsm_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_fsm_state <= TX_IDLE;
            tx_start     <= 0;
            tx_fifo_pop  <= 0;
        end
        else begin
            tx_start    <= 0;
            tx_fifo_pop <= 0;
            case (tx_fsm_state)
                TX_IDLE: begin
                    if (!tx_fifo_empty && !tx_busy) begin
                        tx_fifo_pop  <= 1; // Pull from FIFO
                        tx_fsm_state <= TX_START_BYTE;
                    end
                end
                TX_START_BYTE: begin
                    tx_start     <= 1; // Pulse tx_start
                    tx_fsm_state <= TX_IDLE;
                end
            endcase
        end
    end

    // 4. UART Receiver
    uart_rx rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(rx_pin),
        .s_tick(s_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    // 5. Receiver FIFO
    fifo #(.FIFO_DEPTH(FIFO_DEPTH)) rx_fifo_inst (
        .clk(clk),
        .rst(rst),
        .push(rx_done),
        .pop(rx_pop),
        .data_in(rx_data),
        .data_out(rx_dout),
        .full(), // Could add overflow detection here
        .empty(rx_empty),
        .count(rx_count)
    );

endmodule
