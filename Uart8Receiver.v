`include "UartStates.vh"

/*
 * 8-bit UART Receiver
 *
 * Able to receive 8 bits of serial data, one start bit, one stop bit
 *
 * When receive is detected and in progress over {in}, {busy} is driven high
 *
 * When receive is complete, {done} is driven high for one serial bit cycle
 *   (aka baud interval: equal to 16 {clk} ticks)
 *
 * Output data should be taken away within one baud interval or it will be lost
 *
 * System clock must be divided down to oversampling rate times baud rate
 *   to provide the {clk} input
 *
 * (*Note this module's logic is hard-coded based on 16x oversampling rate)
 */
module Uart8Receiver (
    input wire clk,      // rx data sampling rate
    input wire en,
    input wire in,       // rx line
    output reg busy,     // transaction is in progress
    output reg done,     // end of transaction
    output reg err,      // error while receiving data
    output reg [7:0] out // received data
);

reg [2:0] state         = `RESET;
reg [2:0] bit_index     = 3'b0; // index for 8-bit data
reg [1:0] in_reg        = 2'b0; // shift reg for input signal conditioning
reg [4:0] in_hold_reg   = 5'b0; // shift reg for signal hold time checks
reg [3:0] sample_count  = 4'b0; // count ticks for 16x oversample
reg [3:0] valid_count   = 4'b0; // count ticks before clearing output data
reg was_stop_good       = 1'b0;
reg [7:0] received_data = 8'b0; // storage for the deserialized data
wire in_sample;
wire [3:0] in_prior_hold_reg;
wire [3:0] in_current_hold_reg;

/*
 * Double-register the incoming data:
 *
 * This prevents metastability problems crossing into rx clock domain
 *
 * After registering, only the {in_sample} wire is to be accessed - the
 *   earlier, unconditioned signal {in} must be ignored
 */
always @(posedge clk) begin
    in_reg <= { in_reg[0], in };
end

assign in_sample = in_reg[1];

/*
 * Track the incoming data for 4 rx {clk} ticks + 1, to be able to enforce a
 *   minimum hold time of 4 {clk} ticks for any rx signal
 */
always @(posedge clk) begin
    in_hold_reg <= { in_hold_reg[3:1], in_sample, in_reg[0] };
end

assign in_prior_hold_reg   = in_hold_reg[4:1];
assign in_current_hold_reg = in_hold_reg[3:0];

/*
 * End the validity of output data after precise time of one serial bit cycle:
 *
 * Output signals from this module might as well be consistent with input
 *   rate, which is the baud rate
 *
 * This hold is for the case when detection of a next transmit cut short
 *   the prior stop and ready transitions; i.e. IDLE state was entered direct
 *   from STOP_BIT state
 */
always @(posedge clk) begin
    if (|valid_count) begin
        valid_count <= valid_count + 4'b1;
        if (&valid_count) begin // reached 15 - timed output interval ends
            out     <= 8'b0;
        end
    end
end

always @(posedge clk) begin
    if (!en) begin
        state <= `RESET;
    end

    case (state)
        `RESET: begin
            busy          <= 1'b0;
            done          <= 1'b0;
            err           <= 1'b0;
            sample_count  <= 4'b0;
            was_stop_good <= 1'b0;
            received_data <= 8'b0;
            out           <= 8'b0;
            if (en) begin
                state     <= `IDLE;
            end
        end

        `IDLE: begin
            /*
             * Accept low-going input as the trigger to start:
             *
             * Count from the first low sample, and sample again at the
             *   mid-point of a full baud interval to accept the low signal
             *
             * Then start the count for the proceeding full baud intervals
             */
            if (!in_sample) begin
                if (sample_count == 4'b0) begin
                    if (&in_prior_hold_reg) begin
                        // meets min previous high signal
                        err           <= 1'b0;
                        sample_count  <= sample_count + 4'b1;
                    end else begin
                        err           <= 1'b1;
                    end
                end else begin
                    sample_count      <= sample_count + 4'b1;
                    if (&sample_count[2:0]) begin // reached 7
                        busy          <= 1'b1;
                        done          <= 1'b0;
                        err           <= 1'b0;
                        sample_count  <= 4'b0; // start the interval count over
                        was_stop_good <= 1'b0;
                        state         <= `START_BIT;
                    end
                end
            end else if (|sample_count) begin
                // bit did not remain low while waiting till 7 -
                // remain in IDLE state
                err                   <= 1'b1;
                sample_count          <= 4'b0;
                received_data         <= 8'b0;
            end
        end

        `START_BIT: begin
            /*
             * Wait one full baud interval to the mid-point of first bit
             */
            sample_count      <= sample_count + 4'b1;
            if (&sample_count) begin // reached 15
                received_data <= { 7'b0, in_sample };
                out           <= 8'b0;
                bit_index     <= 3'b1;
                state         <= `DATA_BITS;
            end
        end

        `DATA_BITS: begin
            /*
             * Take 8 baud intervals to receive serial data
             */
            if (&sample_count) begin // save one bit of received data
                sample_count             <= 4'b0;
                received_data[bit_index] <= in_sample;
                if (&bit_index) begin
                    bit_index            <= 3'b0;
                    state                <= `STOP_BIT;
                end else begin
                    bit_index            <= bit_index + 3'b1;
                end
            end else begin
                sample_count             <= sample_count + 4'b1;
            end
        end

        `STOP_BIT: begin
            /*
             * Accept the received data if input goes high:
             *
             * If stop signal condition(s) met, drive the {done} signal high
             *   for one bit cycle
             *
             * Otherwise drive the {err} signal high for one bit cycle
             *
             * Since this baud clock may not track the transmitter baud clock
             *   precisely in reality, accept the transition to handling the
             *   next start bit any time after the stop bit mid-point
             */
            sample_count              <= sample_count + 4'b1;
            if (sample_count[3]) begin // reached 8 to 15
                if (sample_count == 4'b1000 &&
                        &in_current_hold_reg) begin // meets min high hold time
                    was_stop_good     <= 1'b1;
                end

                if (!in_sample) begin
                    // accept that transmission has completed only if the stop
                    // signal held for a time of >= 4 rx ticks before it
                    // changed to a start signal
                    if (was_stop_good) begin
                        // can accept the transmitted data and output it
                        done          <= 1'b1;
                        out           <= received_data;
                        valid_count   <= sample_count;
                        sample_count  <= 4'b0;
                        state         <= `IDLE;
                    end else if (&sample_count) begin // reached 15
                        // bit did not go high or remain high -
                        // signal {err} for this transmit
                        busy          <= 1'b0;
                        err           <= 1'b1;
                        sample_count  <= 4'b0;
                        received_data <= 8'b0;
                        state         <= `IDLE;
                    end
                end else begin
                    if (&in_current_hold_reg) begin // meets min high hold time
                        // can accept the transmitted data and output it
                        done          <= 1'b1;
                        out           <= received_data;
                        sample_count  <= 4'b0;
                        state         <= `READY;
                    end else if (&sample_count) begin // reached 15
                        // signal {err} for this transmit
                        err           <= 1'b1;
                        sample_count  <= 4'b0;
                        state         <= `READY;
                    end
                end
            end
        end

        `READY: begin
            /*
             * Wait one full bit cycle to sustain the {out} data, the
             *   {done} signal or the {err} signal
             */
            sample_count     <= sample_count + 4'b1;
            if (!err && !in_sample) begin
                // accept the trigger to start, immediately following
                // transmission stop
                valid_count  <= sample_count;
                sample_count <= 4'b0;
                state        <= `IDLE;
            end else if (&sample_count[3:1]) begin // reached 14 -
                // additional tick 15 comes from transitting the READY state
                // to the RESET state
                state        <= `RESET;
            end
        end

        default: begin
            state <= `RESET;
        end
    endcase
end

endmodule