`timescale 1ns/1ps

module layer_tb;

    localparam int BEAT_WIDTH     = 4;
    localparam int NUM_INPUTS     = 8;
    localparam int NUM_NEURONS    = 3;
    localparam int POPCOUNT_WIDTH = 8;

    logic clk;
    logic rst;
    logic en;
    logic valid_in;
    logic last;
    logic [BEAT_WIDTH-1:0] x;
    logic [NUM_NEURONS-1:0][BEAT_WIDTH-1:0] w;
    logic [NUM_NEURONS-1:0][POPCOUNT_WIDTH-1:0] thresholds;

    logic [NUM_NEURONS-1:0] out;
    logic [NUM_NEURONS-1:0][POPCOUNT_WIDTH-1:0] popcount_outs;
    logic [NUM_NEURONS-1:0] valid_outs;

    layer #(
        .BEAT_WIDTH(BEAT_WIDTH),
        .NUM_INPUTS(NUM_INPUTS),
        .NUM_NEURONS(NUM_NEURONS),
        .POPCOUNT_WIDTH(POPCOUNT_WIDTH)
    ) dut (
        .clk(clk),
        .x(x),
        .thresholds(thresholds),
        .rst(rst),
        .en(en),
        .valid_in(valid_in),
        .last(last),
        .w(w),
        .out(out),
        .popcount_outs(popcount_outs),
        .valid_outs(valid_outs)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic send_beat(
        input logic [BEAT_WIDTH-1:0] x_in,
        input logic [NUM_NEURONS-1:0][BEAT_WIDTH-1:0] w_in,
        input logic valid_in_in,
        input logic last_in
    );
    begin
        @(negedge clk);
        x        = x_in;
        w        = w_in;
        valid_in = valid_in_in;
        last     = last_in;
    end
    endtask

    initial begin
        rst        = 1'b1;
        en         = 1'b1;
        valid_in   = 1'b0;
        last       = 1'b0;
        x          = '0;
        w          = '0;
        thresholds = '0;

        // Expected totals:
        // neuron 0 = 8
        // neuron 1 = 0
        // neuron 2 = 4
        thresholds[0] = 8'd6;   // expect out[0] = 1
        thresholds[1] = 8'd1;   // expect out[1] = 0
        thresholds[2] = 8'd4;   // expect out[2] = 1 if >=

        repeat (2) @(posedge clk);
        rst = 1'b0;

        $display("Starting layer test...");

        // Beat 0
        // x = 1010
        // neuron0 w = 1010 -> xnor popcount = 4
        // neuron1 w = 0101 -> xnor popcount = 0
        // neuron2 w = 1111 -> xnor popcount = 2
        send_beat(
            4'b1010,
            '{4'b1111, 4'b0101, 4'b1010},
            1'b1,
            1'b0
        );

        // Beat 1
        // x = 1100
        // neuron0 w = 1100 -> xnor popcount = 4   total = 8
        // neuron1 w = 0011 -> xnor popcount = 0   total = 0
        // neuron2 w = 1001 -> xnor popcount = 2   total = 4
        send_beat(
            4'b1100,
            '{4'b1001, 4'b0011, 4'b1100},
            1'b1,
            1'b1
        );

        // idle after sample
        send_beat(
            '0,
            '{default:'0},
            1'b0,
            1'b0
        );

        // wait until outputs are actually valid
        wait (valid_outs[0] == 1'b1);
        @(negedge clk);

        $display("valid_outs       = %b", valid_outs);
        $display("popcount_outs[0] = %0d", popcount_outs[0]);
        $display("popcount_outs[1] = %0d", popcount_outs[1]);
        $display("popcount_outs[2] = %0d", popcount_outs[2]);
        $display("out              = %b", out);

        if (popcount_outs[0] !== 8)
            $error("Neuron 0 popcount wrong. Expected 8, got %0d", popcount_outs[0]);

        if (popcount_outs[1] !== 0)
            $error("Neuron 1 popcount wrong. Expected 0, got %0d", popcount_outs[1]);

        if (popcount_outs[2] !== 4)
            $error("Neuron 2 popcount wrong. Expected 4, got %0d", popcount_outs[2]);

        if (out[0] !== 1'b1)
            $error("Neuron 0 out wrong. Expected 1, got %b", out[0]);

        if (out[1] !== 1'b0)
            $error("Neuron 1 out wrong. Expected 0, got %b", out[1]);

        if (out[2] !== 1'b1)
            $error("Neuron 2 out wrong. Expected 1, got %b", out[2]);

        $display("Layer test PASSED.");
        $finish;
    end

endmodule