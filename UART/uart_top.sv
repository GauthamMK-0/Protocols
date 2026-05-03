module uart_top #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic clk,
    input  logic rst,
    
    // Transmitter Interface
    input  logic tx_start,
    input  logic [7:0] tx_data,
    output logic tx,
    output logic tx_busy,
    
    // Receiver Interface
    input  logic rx,
    output logic [7:0] rx_data,
    output logic rx_done
);

    logic s_tick;

    // Instantiate Baud Rate Generator
    baud_rate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) brg_inst (
        .clk(clk),
        .rst(rst),
        .divisor(16'd0), // Use default calculation
        .tick(s_tick)
    );

    // Instantiate Transmitter
    uart_tx tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .s_tick(s_tick),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    // Instantiate Receiver
    uart_rx rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .s_tick(s_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

endmodule
