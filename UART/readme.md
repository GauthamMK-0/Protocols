# UART Protocol Modules

This directory contains a simple UART transmitter and receiver implemented in SystemVerilog.
The UART modules support 8-bit data transfers at a configurable baud rate and clock frequency.

## Overview

UART (Universal Asynchronous Receiver/Transmitter) is a serial communication protocol that sends data one bit at a time over a single wire.
It uses a fixed baud rate and frames each byte with a start bit and a stop bit.

This project includes:
- `uart_tx.sv`: UART transmitter module
- `uart_rx.sv`: UART receiver module

## How UART Works Here

Each UART frame consists of:
1. Start bit: logic `0`
2. Data bits: 8 bits, least-significant bit first
3. Stop bit: logic `1`

The modules derive their internal timing from a system clock and the `BAUD_RATE` parameter.
The number of clock cycles per UART bit is calculated as:

```
CLKS_PER_BIT = CLK_FREQ / BAUD_RATE
```

This divides the system clock into precise intervals for sending or sampling each UART bit.

## Transmitter (`uart_tx.sv`)

### Function

The transmitter accepts an 8-bit input `tx_data` and a `tx_start` request.
When `tx_start` is asserted, the transmitter begins sending a full UART frame on the `tx` output.
The `tx_busy` output indicates that a transfer is in progress.

### State machine

The transmitter uses four states:
- `IDLE`: wait for `tx_start`
- `START`: drive the start bit (`0`)
- `DATA`: shift out 8 data bits
- `STOP`: drive the stop bit (`1`)

### Dataflow

```mermaid
flowchart TD
    A[tx_start asserted] --> B[Load tx_data into data_reg]
    B --> C[START state: tx <= 0]
    C --> D[DATA state: tx <= data_reg[bit_index]]
    D --> E{bit_index < 7}
    E -- yes --> F[bit_index += 1]
    E -- no --> G[STOP state: tx <= 1]
    G --> H[Return to IDLE]
```

### Timing

- In `START`, the module holds `tx = 0` for `CLKS_PER_BIT` clock cycles.
- In `DATA`, each bit is held for `CLKS_PER_BIT` cycles.
- In `STOP`, the line is held high for `CLKS_PER_BIT` cycles.

The transmitter is idle-high, so `tx` remains `1` when no transmission is active.

## Receiver (`uart_rx.sv`)

### Function

The receiver monitors the serial input `rx`.
When it sees a falling edge to `0`, it begins sampling the incoming frame.
At the end of a valid frame, the received byte appears on `rx_data` and `rx_done` pulses high.

### State machine

The receiver also uses four states:
- `IDLE`: wait for a start bit (`rx == 0`)
- `START`: validate the start bit at the middle of the bit period
- `DATA`: sample 8 data bits
- `STOP`: wait for the stop bit and finalize the byte

### Dataflow

```mermaid
flowchart TD
    A[rx line idle high] --> B[Detect rx == 0]
    B --> C[START state: wait half bit period]
    C --> D[Confirm start bit still 0]
    D --> E[DATA state: sample rx each bit period]
    E --> F[Store sampled bit into data_reg[bit_index]]
    F --> G{bit_index < 7}
    G -- yes --> H[bit_index += 1]
    G -- no --> I[STOP state: wait full stop bit period]
    I --> J[Output rx_data and assert rx_done]
    J --> K[Return to IDLE]
```

### Timing and sampling

- In `START`, the receiver waits `CLKS_PER_BIT / 2` cycles to sample near the middle of the start bit.
- In `DATA`, it samples each bit once every `CLKS_PER_BIT` cycles.
- In `STOP`, it waits one full bit period before accepting the next frame.

This mid-bit sampling improves noise immunity and ensures stable data capture.

## Parameterization

Both modules use the same parameters:
- `CLK_FREQ`: system clock frequency in hertz (default `50_000_000`)
- `BAUD_RATE`: UART baud rate (default `115200`)

Adjust these parameters to match the clock domain and serial speed of your design.

## Example Usage

### Transmitter

```verilog
uart_tx #(
    .CLK_FREQ(50_000_000),
    .BAUD_RATE(115200)
) tx_inst (
    .clk(clk),
    .rst(rst),
    .tx_start(tx_start),
    .tx_data(tx_byte),
    .tx(tx_line),
    .tx_busy(tx_busy)
);
```

### Receiver

```verilog
uart_rx #(
    .CLK_FREQ(50_000_000),
    .BAUD_RATE(115200)
) rx_inst (
    .clk(clk),
    .rst(rst),
    .rx(rx_line),
    .rx_data(rx_byte),
    .rx_done(rx_done)
);
```

## Notes

- The receiver does not implement parity or framing error detection.
- The transmitter is ready to send again after the stop bit completes and returns to `IDLE`.
- The receiver asserts `rx_done` for one cycle when a byte has been received.

## Summary

These modules form a simple synchronous UART link:
- `uart_tx` converts parallel bytes into asynchronous serial frames.
- `uart_rx` converts those serial frames back into parallel bytes.

The state machines and clock-derived timing ensure reliable bit-level transmission and reception at the chosen baud rate.
