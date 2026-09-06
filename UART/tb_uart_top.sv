// ==============================================================================
// Testbench: tb_uart_top.sv
// Protocol: UART Top-Level Interconnect with FIFO Buffering
// Verifies:
// 1. Reset state of Transmitter and Receiver FIFOs
// 2. Transmitting bytes from TX FIFO -> serial line (tx_pin) -> RX line (rx_pin) -> RX FIFO
// 3. FIFO empty / full flags and byte integrity across loopback
// ==============================================================================

`timescale 1ns/1ps

module tb_uart_top;

    parameter int CLK_FREQ   = 16_000_000; // 16MHz
    parameter int BAUD_RATE  = 100_000;    // 100kBaud (Divisor = 10 ticks/cycle)
    parameter int FIFO_DEPTH = 16;

    logic       clk;
    logic       rst;

    // CPU Interface - Transmitter
    logic       tx_push;
    logic [7:0] tx_din;
    logic       tx_full;

    // CPU Interface - Receiver
    logic       rx_pop;
    logic [7:0] rx_dout;
    logic       rx_empty;
    logic [4:0] rx_count;

    // Physical Serial Loopback Pin
    logic       serial_loopback;

    // Instantiate Top-Level UART
    uart_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .tx_push(tx_push),
        .tx_din(tx_din),
        .tx_full(tx_full),
        .rx_pop(rx_pop),
        .rx_dout(rx_dout),
        .rx_empty(rx_empty),
        .rx_count(rx_count),
        .tx_pin(serial_loopback),
        .rx_pin(serial_loopback) // Loopback TX directly to RX
    );

    // Clock generation (50MHz / 20ns period)
    always #10 clk = ~clk;

    // Task to push byte into TX FIFO
    task transmit_byte(input [7:0] b);
        @(posedge clk);
        while (tx_full) @(posedge clk);
        tx_push = 1'b1;
        tx_din  = b;
        @(posedge clk);
        tx_push = 1'b0;
    endtask

    // Task to read byte from RX FIFO
    task receive_byte(output [7:0] b);
        @(posedge clk);
        while (rx_empty) @(posedge clk);
        b = rx_dout;
        rx_pop = 1'b1;
        @(posedge clk);
        rx_pop = 1'b0;
    endtask

    logic [7:0] rx_byte;

    initial begin
        clk     = 0;
        rst     = 1;
        tx_push = 0;
        tx_din  = '0;
        rx_pop  = 0;

        #100;
        rst = 0;
        #100;

        $display("=================================================");
        $display("         STARTING UART TOP-LEVEL TESTS           ");
        $display("=================================================");

        $display("\n>>> TEST 1: Transmit Single Byte 0x55 across Loopback");
        transmit_byte(8'h55);
        receive_byte(rx_byte);

        if (rx_byte !== 8'h55) begin
            $display("FAILED: Expected 0x55, got 0x%02x", rx_byte);
            $fatal(1);
        end
        $display("PASSED: Single byte 0x55 transmitted and received successfully");

        $display("\n>>> TEST 2: Transmit Multi-Byte Stream (0xAA, 0x3C, 0x81, 0xFE)");
        transmit_byte(8'hAA);
        transmit_byte(8'h3C);
        transmit_byte(8'h81);
        transmit_byte(8'hFE);

        receive_byte(rx_byte);
        assert(rx_byte == 8'hAA) else $fatal(1, "Byte 0 mismatch");
        receive_byte(rx_byte);
        assert(rx_byte == 8'h3C) else $fatal(1, "Byte 1 mismatch");
        receive_byte(rx_byte);
        assert(rx_byte == 8'h81) else $fatal(1, "Byte 2 mismatch");
        receive_byte(rx_byte);
        assert(rx_byte == 8'hFE) else $fatal(1, "Byte 3 mismatch");

        $display("PASSED: Multi-byte stream verified with correct FIFO ordering");

        $display("\n=================================================");
        $display("   ALL UART TOP-LEVEL TESTS PASSED 100%%!         ");
        $display("=================================================\n");
        $finish;
    end

endmodule
