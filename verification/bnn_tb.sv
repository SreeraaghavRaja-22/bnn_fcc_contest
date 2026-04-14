`timescale 1ns/1ps

module bnn_tb;

    localparam int NUM_INPUTS      = 4;
    localparam int L1_NEURONS      = 4;
    localparam int L2_NEURONS      = 4;
    localparam int L3_NEURONS      = 2;
    localparam int BEAT_WIDTH      = 2;
    localparam int POPCOUNT_WIDTH  = 8;

    logic clk;
    logic rst;
    logic en;

    logic [BEAT_WIDTH-1:0] data_in;
    logic data_in_valid;
    logic data_in_last;

    logic [L1_NEURONS-1:0][BEAT_WIDTH-1:0] l1_w;
    logic [L1_NEURONS-1:0][POPCOUNT_WIDTH-1:0] l1_thresholds;

    logic [L2_NEURONS-1:0][BEAT_WIDTH-1:0] l2_w;
    logic [L2_NEURONS-1:0][POPCOUNT_WIDTH-1:0] l2_thresholds;

    logic [L3_NEURONS-1:0][BEAT_WIDTH-1:0] l3_w;

    logic [L3_NEURONS-1:0][POPCOUNT_WIDTH-1:0] final_popcounts;
    logic final_valid;

    integer error_count;

    bnn #(
        .NUM_INPUTS(NUM_INPUTS),
        .L1_NEURONS(L1_NEURONS),
        .L2_NEURONS(L2_NEURONS),
        .L3_NEURONS(L3_NEURONS),
        .BEAT_WIDTH(BEAT_WIDTH),
        .POPCOUNT_WIDTH(POPCOUNT_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_last(data_in_last),
        .l1_w(l1_w),
        .l1_thresholds(l1_thresholds),
        .l2_w(l2_w),
        .l2_thresholds(l2_thresholds),
        .l3_w(l3_w),
        .final_popcounts(final_popcounts),
        .final_valid(final_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic drive_input_beat(
        input logic [BEAT_WIDTH-1:0] din,
        input logic last_flag
    );
    begin
        @(negedge clk);
        data_in       = din;
        data_in_valid = 1'b1;
        data_in_last  = last_flag;
    end
    endtask

    task automatic idle_inputs();
    begin
        @(negedge clk);
        data_in       = '0;
        data_in_valid = 1'b0;
        data_in_last  = 1'b0;
    end
    endtask

    task automatic reset_dut();
    begin
        @(negedge clk);
        rst           = 1'b1;
        en            = 1'b1;
        data_in       = '0;
        data_in_valid = 1'b0;
        data_in_last  = 1'b0;
        l1_w          = '0;
        l2_w          = '0;
        l3_w          = '0;
        l1_thresholds = '0;
        l2_thresholds = '0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
    end
    endtask

    task automatic record_error(input string msg);
    begin
        error_count = error_count + 1;
        $error("%s", msg);
    end
    endtask

    task automatic test_smoke();
    begin
        $display("========================================");
        $display("Starting BNN smoke test...");
        $display("========================================");

        reset_dut();

        l1_thresholds[0] = 8'd3;
        l1_thresholds[1] = 8'd3;
        l1_thresholds[2] = 8'd2;
        l1_thresholds[3] = 8'd3;

        l2_thresholds[0] = 8'd1;
        l2_thresholds[1] = 8'd1;
        l2_thresholds[2] = 8'd1;
        l2_thresholds[3] = 8'd1;

        // L1 beat 0 weights
        l1_w[0] = 2'b10;
        l1_w[1] = 2'b01;
        l1_w[2] = 2'b11;
        l1_w[3] = 2'b10;

        // L2 weights
        l2_w[0] = 2'b10;
        l2_w[1] = 2'b01;
        l2_w[2] = 2'b10;
        l2_w[3] = 2'b01;

        // L3 weights
        l3_w[0] = 2'b10;
        l3_w[1] = 2'b01;

        drive_input_beat(2'b10, 1'b0);

        @(negedge clk);
        data_in       = 2'b01;
        data_in_valid = 1'b1;
        data_in_last  = 1'b1;

        l1_w[0] = 2'b01;
        l1_w[1] = 2'b10;
        l1_w[2] = 2'b00;
        l1_w[3] = 2'b01;

        idle_inputs();

        wait (final_valid == 1'b1);
        @(negedge clk);

        $display("Smoke: final_valid        = %b", final_valid);
        $display("Smoke: final_popcounts[0] = %0d", final_popcounts[0]);
        $display("Smoke: final_popcounts[1] = %0d", final_popcounts[1]);

        if (final_valid !== 1'b1)
            record_error("Smoke test: Expected final_valid = 1");

        if (^final_popcounts[0] === 1'bx)
            record_error("Smoke test: final_popcounts[0] is X");

        if (^final_popcounts[1] === 1'bx)
            record_error("Smoke test: final_popcounts[1] is X");

        if (error_count == 0)
            $display("BNN smoke test PASSED.");
        else
            $display("BNN smoke test finished with %0d error(s).", error_count);
    end
    endtask

    task automatic test_directed();
    begin
        $display("========================================");
        $display("Starting BNN directed test...");
        $display("========================================");

        reset_dut();

        // Expected:
        // l1_out = 4'b1101
        // l2 stream = 2'b01, 2'b11
        // l2_out = 4'b1111
        // l3 stream = 2'b11, 2'b11
        // final_popcounts = {2,2}

        l1_thresholds[0] = 8'd3;
        l1_thresholds[1] = 8'd3;
        l1_thresholds[2] = 8'd2;
        l1_thresholds[3] = 8'd3;

        l2_thresholds[0] = 8'd1;
        l2_thresholds[1] = 8'd1;
        l2_thresholds[2] = 8'd1;
        l2_thresholds[3] = 8'd1;

        // beat 0 weights
        l1_w[0] = 2'b10;
        l1_w[1] = 2'b01;
        l1_w[2] = 2'b11;
        l1_w[3] = 2'b10;

        l2_w[0] = 2'b10;
        l2_w[1] = 2'b01;
        l2_w[2] = 2'b10;
        l2_w[3] = 2'b01;

        l3_w[0] = 2'b10;
        l3_w[1] = 2'b01;

        drive_input_beat(2'b10, 1'b0);

        @(negedge clk);
        data_in       = 2'b01;
        data_in_valid = 1'b1;
        data_in_last  = 1'b1;

        l1_w[0] = 2'b01;
        l1_w[1] = 2'b10;
        l1_w[2] = 2'b00;
        l1_w[3] = 2'b01;

        idle_inputs();

        wait (dut.l1_valids == '1);
        @(negedge clk);

        $display("Directed: L1 out = %b", dut.l1_out);
        if (dut.l1_out !== 4'b1101)
            record_error($sformatf("Directed test: L1 output wrong. Expected 1101, got %b", dut.l1_out));

        // Check L1 -> L2 serialization by counter value
        wait (dut.l2_valid_in && dut.l1_out_counter_r == 0);
        @(negedge clk);
        if (dut.l2_in !== 2'b01 || dut.l2_last !== 1'b0)
            record_error($sformatf("Directed test: L1->L2 beat 0 wrong. in=%b last=%b",
                                   dut.l2_in, dut.l2_last));

        wait (dut.l2_valid_in && dut.l1_out_counter_r == 1);
        @(negedge clk);
        if (dut.l2_in !== 2'b11 || dut.l2_last !== 1'b1)
            record_error($sformatf("Directed test: L1->L2 beat 1 wrong. in=%b last=%b",
                                   dut.l2_in, dut.l2_last));

        wait (dut.l2_valids == '1);
        @(negedge clk);

        $display("Directed: L2 out = %b", dut.l2_out);
        if (dut.l2_out !== 4'b1111)
            record_error($sformatf("Directed test: L2 output wrong. Expected 1111, got %b", dut.l2_out));

        // Check L2 -> L3 serialization by counter value
        wait (dut.l3_valid_in && dut.l2_out_counter_r == 0);
        @(negedge clk);
        if (dut.l3_in !== 2'b11 || dut.l3_last !== 1'b0)
            record_error($sformatf("Directed test: L2->L3 beat 0 wrong. in=%b last=%b",
                                   dut.l3_in, dut.l3_last));

        wait (dut.l3_valid_in && dut.l2_out_counter_r == 1);
        @(negedge clk);
        if (dut.l3_in !== 2'b11 || dut.l3_last !== 1'b1)
            record_error($sformatf("Directed test: L2->L3 beat 1 wrong. in=%b last=%b",
                                   dut.l3_in, dut.l3_last));

        wait (final_valid == 1'b1);
        @(negedge clk);

        $display("Directed: final_valid        = %b", final_valid);
        $display("Directed: final_popcounts[0] = %0d", final_popcounts[0]);
        $display("Directed: final_popcounts[1] = %0d", final_popcounts[1]);

        if (final_valid !== 1'b1)
            record_error("Directed test: Expected final_valid = 1");

        if (final_popcounts[0] !== 8'd2)
            record_error($sformatf("Directed test: final_popcounts[0] wrong. Expected 2, got %0d",
                                   final_popcounts[0]));

        if (final_popcounts[1] !== 8'd2)
            record_error($sformatf("Directed test: final_popcounts[1] wrong. Expected 2, got %0d",
                                   final_popcounts[1]));

        if (error_count == 0)
            $display("BNN directed test PASSED.");
        else
            $display("BNN directed test finished with %0d total error(s) so far.", error_count);
    end
    endtask

    initial begin
        rst           = 1'b1;
        en            = 1'b1;
        data_in       = '0;
        data_in_valid = 1'b0;
        data_in_last  = 1'b0;
        l1_w          = '0;
        l2_w          = '0;
        l3_w          = '0;
        l1_thresholds = '0;
        l2_thresholds = '0;
        error_count   = 0;

        test_smoke();
        test_directed();

        $display("========================================");
        if (error_count == 0)
            $display("All BNN tests PASSED.");
        else
            $display("BNN tests finished with %0d error(s).", error_count);
        $display("========================================");
        $finish;
    end

endmodule