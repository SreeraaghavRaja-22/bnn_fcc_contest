`timescale 1ns/1ps

module argmax_tb;

    localparam int NUM_OUTPUTS = 10;
    localparam int COUNT_WIDTH = 32;

    logic clk;
    logic rst;
    logic en;
    logic last;
    logic [NUM_OUTPUTS-1:0] neuron_inputs;
    logic [$clog2(NUM_OUTPUTS)-1:0] max_val;

    argmax #(
        .NUM_OUTPUTS(NUM_OUTPUTS),
        .COUNT_WIDTH(COUNT_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .last(last),
        .neuron_inputs(neuron_inputs),
        .max_val(max_val)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic send_inputs(
        input logic [NUM_OUTPUTS-1:0] inputs,
        input logic last_flag
    );
    begin
        @(negedge clk);
        neuron_inputs = inputs;
        last          = last_flag;
    end
    endtask

    initial begin
        rst = 1;
        en = 1;
        last = 0;
        neuron_inputs = '0;

        repeat (2) @(posedge clk);
        rst = 0;

        // TEST 1
        $display("TEST 1 starting...");
        send_inputs(10'b0000001000, 0); // idx 3
        send_inputs(10'b0000001010, 0); // idx 3,1
        send_inputs(10'b0010001000, 0); // idx 7,3
        send_inputs(10'b0000000010, 1); // idx 1 and last

        @(posedge clk);
        @(posedge clk);
        @(negedge clk);

        if (max_val == 3)
            $display("TEST 1 PASS: max_val = %0d", max_val);
        else
            $error("TEST 1 FAIL: expected 3, got %0d", max_val);

        // TEST 2
        $display("TEST 2 starting...");
        send_inputs(10'b0000000010, 0); // idx 1
        send_inputs(10'b0000000010, 0); // idx 1
        send_inputs(10'b0000010000, 0); // idx 4
        send_inputs(10'b0000000010, 1); // idx 1 and last

        @(posedge clk);
        @(posedge clk);
        @(negedge clk);

        if (max_val == 1)
            $display("TEST 2 PASS: max_val = %0d", max_val);
        else
            $error("TEST 2 FAIL: expected 1, got %0d", max_val);

        // TEST 3
        $display("TEST 3 starting...");
        send_inputs(10'b0000100100, 0); // idx 5 and 2
        send_inputs(10'b0000100000, 0); // idx 5
        send_inputs(10'b0000000100, 1); // idx 2 and last

        @(posedge clk);
        @(posedge clk);
        @(negedge clk);

        if (max_val == 2)
            $display("TEST 3 PASS: max_val = %0d", max_val);
        else
            $error("TEST 3 FAIL: expected 2, got %0d", max_val);

        $display("All tests done.");
        $finish;
    end

endmodule