`timescale 100ns/1ns
`default_nettype none

`include "Uart8.v"

module test;

localparam CLOCK_FREQ = 12000000; // Alhambra board
localparam SIM_STEP_FREQ = 1 / 0.0000001 / 2; // this sim timescale 100ns

// for the simulation timeline:
// ratio SIM_STEP_FREQ MHz / CLOCK_FREQ MHz gives the output waveform in proper time
// (*but note all clocks and the timeline are approximate due to rounding)
localparam SIM_TIMESTEP_FACTOR = SIM_STEP_FREQ / CLOCK_FREQ;

localparam ENABLED_BAUD_CLOCK_STEPS = 13;

reg        clk;
reg        en_1;
reg        en_2;
reg        txStart_1;
reg        txStart_2;
wire       txBusy_1;
wire       txBusy_2;
wire       rxBusy_1;
wire       rxBusy_2;
wire       txDone_1;
wire       txDone_2;
wire       rxDone_1;
wire       rxDone_2;
wire       rxErr_1;
wire       rxErr_2;
reg [7:0]  txByte_1;
reg [7:0]  txByte_2;
wire [7:0] rxByte_1;
wire [7:0] rxByte_2;
wire       bus_wire_1_2;
wire       bus_wire_2_1;
integer c;

Uart8 #(.CLOCK_RATE(CLOCK_FREQ), .TURBO_FRAMES(1)) uart1(
  .clk(clk),

  // rx interface
  .rxEn(en_2),
  .rx(bus_wire_2_1),
  .rxBusy(rxBusy_1),
  .rxDone(rxDone_1),
  .rxErr(rxErr_1),
  .out(rxByte_1),

  // tx interface
  .txEn(en_1),
  .txStart(txStart_1),
  .in(txByte_1),
  .txBusy(txBusy_1),
  .txDone(txDone_1),
  .tx(bus_wire_1_2)
);

Uart8 #(.CLOCK_RATE(CLOCK_FREQ)) uart2(
  .clk(clk),

  // rx interface
  .rxEn(en_1),
  .rx(bus_wire_1_2),
  .rxBusy(rxBusy_2),
  .rxDone(rxDone_2),
  .rxErr(rxErr_2),
  .out(rxByte_2),

  // tx interface
  .txEn(en_2),
  .txStart(txStart_2),
  .in(txByte_2),
  .txBusy(txBusy_2),
  .txDone(txDone_2),
  .tx(bus_wire_2_1)
);

initial clk = 1'b0;

always #SIM_TIMESTEP_FACTOR clk = ~clk;

initial c = 1;

always @(posedge uart1.txClk) begin
  // drive the start signal low synchronously from the second last rx done signal
  if (rxDone_2) begin
    c <= c + 1;
    if (c < 2) begin
      txStart_1 <= 1'b0;
    end
  end
end

initial begin
  integer t;

  $dumpfile(`DUMP_FILE_NAME);
  $dumpvars(0, test);

#600
  en_1 = 1'b0;
  txStart_1 = 1'b0;
#600
  en_1 = 1'b1;
  txStart_1 = 1'b1;
#600
  txByte_1 = 8'b01111010;

  $display("%7.2fms | tx start: %d", $realtime/10000, txStart_1);
  $display("%7.2fms | tx data: %8b", $realtime/10000, txByte_1);

  for (t = 0; t < ENABLED_BAUD_CLOCK_STEPS; t++) begin
    // #1000 x 100ns == 0.1ms == 1 tx clock period (approximately) at 9600 baud
#1000
    case (t)
      10: begin
        // before the high-going done signal (so that the IDLE and START_BIT states
        // are not entered with the existing data at tx in)
        txByte_1 = 8'b10110001;

        $display("%7.2fms | tx data: %8b", $realtime/10000, txByte_1);
        $display("%7.2fms | rx done: %d", $realtime/10000, rxDone_2);
        $display("%7.2fms | rx data: %8b", $realtime/10000, rxByte_2);
      end
    endcase
  end

  $display("%7.2fms | rx done: %d", $realtime/10000, rxDone_2);
  $display("%7.2fms | rx data: %8b", $realtime/10000, rxByte_2);

  for (t = 0; t < ENABLED_BAUD_CLOCK_STEPS; t++) begin
#1000
    case (t)
      4: begin
        $display("%7.2fms | tx start: %d", $realtime/10000, txStart_1);
        $display("%7.2fms | rx done: %d", $realtime/10000, rxDone_2);
        $display("%7.2fms | rx data: %8b", $realtime/10000, rxByte_2);
      end
      5: begin
        $display("%7.2fms | tx start: %d", $realtime/10000, txStart_1);
        $display("%7.2fms | rx done: %d", $realtime/10000, rxDone_2);
        $display("%7.2fms | rx data: %8b", $realtime/10000, rxByte_2);
      end
      10: begin
        // output is ready

        $display("%7.2fms | tx start: %d", $realtime/10000, txStart_1);
        $display("%7.2fms | rx done: %d", $realtime/10000, rxDone_2);
        $display("%7.2fms | rx data: %8b", $realtime/10000, rxByte_2);
      end
    endcase
  end

#1100
  en_1 = 1'b0;
#2800

  $finish();
end

endmodule
