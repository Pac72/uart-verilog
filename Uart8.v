`timescale 1ns / 1ps

/*
 * Simple 8-bit UART realization
 *
 * Able to transmit and receive 8 bits of serial data, one start bit,
 *   one stop bit
 */
module Uart8 #(
    parameter CLOCK_RATE   = 100000000, // board clock (default 100MHz)
    parameter BAUD_RATE    = 9600,
    parameter TURBO_FRAMES = 0          // see Uart8Transmitter
)(
    input wire clk, // board clock (*note: at the {CLOCK_RATE} rate)
    input wire reset,

    // rx interface
    input wire rxEn,
    input wire rxIn,
    output wire rxBusy,
    output wire rxDone,
    output wire rxErr,
    output wire [7:0] rxOut,

    // tx interface
    input wire txEn,
    input wire txStart,
    input wire [7:0] txIn,
    output wire txBusy,
    output wire txDone,
    output wire txOut
);

// this value cannot be changed in the current implementation
parameter RX_OVERSAMPLE_RATE = 16;

wire rxClk;
wire txClk;

BaudRateGenerator #(
    .CLOCK_RATE(CLOCK_RATE),
    .BAUD_RATE(BAUD_RATE),
    .RX_OVERSAMPLE_RATE(RX_OVERSAMPLE_RATE)
) generatorInst (
    .clk(clk),
    .reset(reset),
    .rxClk(rxClk),
    .txClk(txClk)
);

Uart8Receiver rxInst (
    .clk(rxClk),
    .en(rxEn),
    .rxIn(rxIn),
    .busy(rxBusy),
    .done(rxDone),
    .err(rxErr),
    .rxOut(rxOut)
);

Uart8Transmitter #(
    .TURBO_FRAMES(TURBO_FRAMES)
) txInst (
    .clk(txClk),
    .en(txEn),
    .start(txStart),
    .txIn(txIn),
    .busy(txBusy),
    .done(txDone),
    .txOut(txOut)
);

endmodule
