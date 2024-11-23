`timescale 100ns/1ns
`default_nettype none

module test;

localparam CLOCK_FREQ = 12000000; // Alhambra board
localparam SIM_STEP_FREQ = 1 / 0.0000001 / 2; // this sim timescale 100ns

// for the simulation timeline:
// ratio SIM_STEP_FREQ MHz / CLOCK_FREQ MHz gives the output waveform in proper time
// (*but note all clocks and the timeline are approximate due to rounding)
localparam SIM_TIMESTEP_FACTOR = SIM_STEP_FREQ / CLOCK_FREQ;

reg        clk;
reg        en_1;
reg        rx;
wire       rxBusy_2;
wire       rxDone_2;
wire       rxErr_2;
reg [7:0]  txByte_1;
wire [7:0] rxByte_2;

Uart8 #(.CLOCK_RATE(CLOCK_FREQ)) uart(
  .clk(clk),

  // rx interface
  .rxEn(en_1),
  .rxIn(rx),
  .rxBusy(rxBusy_2),
  .rxDone(rxDone_2),
  .rxErr(rxErr_2),
  .rxOut(rxByte_2)

  // tx interface (unused)
);

initial clk = 1'b0;

always #SIM_TIMESTEP_FACTOR clk = ~clk;

initial begin
  $dumpfile(`DUMP_FILE_NAME);
  $dumpvars(0, test);

// #65 == 1 rx clock period (approximately) at 9600 baud
// #1042 == 16 rx clock periods (approximately)
// #1075 instead of #1042 makes transmit clock sync with receive clock (a 3% difference)
#240
  en_1 = 1'b1;
  txByte_1 = 8'b00110101;

  $display("            tx data: %8b", txByte_1);
#240
  rx = 1'b1;
#200
  rx = 1'b0;
#1075
  rx = txByte_1[0];

  $display("%7.2fms | rx first bit: %1b", $realtime/10000, rx);
#1075
  rx = txByte_1[1];

  $display("%7.2fms | rx next bit: %1b", $realtime/10000, rx);
#1075
  rx = txByte_1[2];

  $display("%7.2fms | rx next bit: %1b", $realtime/10000, rx);
#1075
  rx = txByte_1[3];

  $display("%7.2fms | rx next bit: %1b", $realtime/10000, rx);
#1075
  rx = txByte_1[4];

  $display("%7.2fms | rx next bit: %1b", $realtime/10000, rx);
#40

  $finish();
end

endmodule
