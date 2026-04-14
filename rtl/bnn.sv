module bnn #(
    parameter int LAYERS  = 3,
    parameter int NUM_INPUTS = 256,
    parameter int L1_NEURONS = 256,
    parameter int L2_NEURONS = 256,
    parameter int L3_NEURONS = 10,
    parameter int BEAT_WIDTH = 16,
    parameter int POPCOUNT_WIDTH = 32
)(
    input logic clk,
    input logic rst,
    input logic en,

    input logic [BEAT_WIDTH-1:0] data_in,
    input logic data_in_valid,
    input logic data_in_last,

    input  logic [L1_NEURONS-1:0][BEAT_WIDTH-1:0] l1_w,
    input  logic [L1_NEURONS-1:0][POPCOUNT_WIDTH-1:0] l1_thresholds,

    input  logic [L2_NEURONS-1:0][BEAT_WIDTH-1:0] l2_w,
    input  logic [L2_NEURONS-1:0][POPCOUNT_WIDTH-1:0] l2_thresholds,

    input  logic [L3_NEURONS-1:0][BEAT_WIDTH-1:0] l3_w,

    output logic [L3_NEURONS-1:0][POPCOUNT_WIDTH-1:0] final_popcounts,
    output logic final_valid
);

    logic [L1_NEURONS-1:0] l1_out;
    logic [L2_NEURONS-1:0] l2_out;

    logic [L1_NEURONS-1:0] l1_valids;
    logic [L2_NEURONS-1:0] l2_valids;
    logic [L3_NEURONS-1:0] l3_valids;

    layer #(
        .BEAT_WIDTH(BEAT_WIDTH),
        .NUM_INPUTS(NUM_INPUTS),
        .NUM_NEURONS(L1_NEURONS),
        .POPCOUNT_WIDTH(POPCOUNT_WIDTH)
    ) L1 (
        .clk(clk),
        .x(data_in),
        .thresholds(l1_thresholds),
        .rst(rst),
        .en(en),
        .valid_in(data_in_valid),
        .last(data_in_last),
        .w(l1_w),
        .out(l1_out),
        .popcount_outs(), // Don't need except in output layer
        .valid_outs(l1_valids)
    );

    localparam int L1_BEATS = (L1_NEURONS + BEAT_WIDTH - 1) / BEAT_WIDTH;
    logic [$clog2(L1_BEATS)-1:0] l1_out_counter, l1_out_counter_r;
    logic l1_to_l2_active_r;
    logic [BEAT_WIDTH-1:0] l2_in;
    logic l2_last;
    logic l2_valid_in;
    logic [L1_NEURONS-1:0] l1_out_r;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            l1_out_counter_r <= '0;
            l1_to_l2_active_r <= 1'b0;
            l1_out_r <= '0;
        end else if (!l1_to_l2_active_r && (l1_valids == '1)) begin
            l1_to_l2_active_r <= 1'b1;
            l1_out_counter_r <= '0;
            l1_out_r <= l1_out;
        end else if (l1_to_l2_active_r) begin
            if (l1_out_counter_r == L1_BEATS-1) begin
                l1_to_l2_active_r <= 1'b0;
                l1_out_counter_r <= '0;
                l1_out_r <= '0;
            end else begin
                l1_out_counter_r <= l1_out_counter_r + 1'b1;
            end
        end
    end
    assign l1_out_counter = l1_out_counter_r;
    assign l2_in = l1_out_r[l1_out_counter*BEAT_WIDTH +: BEAT_WIDTH];
    assign l2_valid_in = l1_to_l2_active_r;
    assign l2_last = l1_to_l2_active_r && (l1_out_counter_r == L1_BEATS - 1);

    layer #(
        .BEAT_WIDTH(BEAT_WIDTH),
        .NUM_INPUTS(L1_NEURONS),
        .NUM_NEURONS(L2_NEURONS),
        .POPCOUNT_WIDTH(POPCOUNT_WIDTH)
    ) L2 (
        .clk(clk),
        .x(l2_in),
        .thresholds(l2_thresholds),
        .rst(rst),
        .en(en),
        .valid_in(l2_valid_in),
        .last(l2_last),
        .w(l2_w),
        .out(l2_out),
        .popcount_outs(), // Don't need except in output layer
        .valid_outs(l2_valids)
    );

    localparam int L2_BEATS = (L2_NEURONS + BEAT_WIDTH - 1) / BEAT_WIDTH;    
    logic [$clog2(L2_BEATS)-1:0] l2_out_counter, l2_out_counter_r;
    logic l2_to_l3_active_r;
    logic [BEAT_WIDTH-1:0] l3_in;
    logic l3_last;
    logic l3_valid_in;
    logic [L2_NEURONS-1:0] l2_out_r;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            l2_out_counter_r <= '0;
            l2_to_l3_active_r <= 1'b0;
            l2_out_r <= '0;
        end else if (!l2_to_l3_active_r && (l2_valids == '1)) begin
            l2_to_l3_active_r <= 1'b1;
            l2_out_counter_r <= '0;
            l2_out_r <= l2_out;
        end else if (l2_to_l3_active_r) begin
            if (l2_out_counter_r == L2_BEATS-1) begin
                l2_to_l3_active_r <= 1'b0;
                l2_out_counter_r <= '0;
                l2_out_r <= '0;
            end else begin
                l2_out_counter_r <= l2_out_counter_r + 1'b1;
            end
        end
    end

    assign l2_out_counter = l2_out_counter_r;
    assign l3_in = l2_out_r[l2_out_counter*BEAT_WIDTH +: BEAT_WIDTH];
    assign l3_valid_in = l2_to_l3_active_r;
    assign l3_last = l2_to_l3_active_r && (l2_out_counter_r == L2_BEATS - 1);

    logic [L3_NEURONS-1:0][POPCOUNT_WIDTH-1:0] l3_thresholds_dummy;
    assign l3_thresholds_dummy = '0;

    layer #(
        .BEAT_WIDTH(BEAT_WIDTH),
        .NUM_INPUTS(L2_NEURONS),
        .NUM_NEURONS(L3_NEURONS),
        .POPCOUNT_WIDTH(POPCOUNT_WIDTH)
    ) L_OUT (
        .clk(clk),
        .x(l3_in),
        .thresholds(l3_thresholds_dummy),
        .rst(rst),
        .en(en),
        .valid_in(l3_valid_in),
        .last(l3_last),
        .w(l3_w),
        .out(), // don't care
        .popcount_outs(final_popcounts),
        .valid_outs(l3_valids)
    );

    assign final_valid = (l3_valids == '1);

endmodule
