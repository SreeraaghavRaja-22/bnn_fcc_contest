/*module config_manager
#(
  parameter int BUS_WIDTH = 64,
  parameter int LAYERS = 3,
  parameter int PARALLEL_INPUTS = 8, 
  parameter int PARALLEL_NEURONS = 8
)(
    input  logic clk, 
    input  logic rst, 
    input  logic [BUS_WIDTH-1:0] config_data,
    input  logic [BUS_WIDTH/8-1:0] config_keep,
    input  logic config_valid, 
    input  logic config_last, 
    output logic config_ready, 
    output logic weight_ram_wr_data, 
    output logic weight_ram_wr_en, 
    output logic threshold_ram_wr_data,
    output logic threshold_ram_wr_en
);


    localparam int HEADER_BITS  = 128;
    localparam int BYTES_PER_BEAT = BUS_WIDTH/8;
    localparam int HEADER_BEATS = (HEADER_BITS + BUS_WIDTH - 1) / BUS_WIDTH;
    localparam int BEAT_COUNT_W = (HEADER_BEATS <= 1) ? 1 : $clog2(HEADER_BEATS);

    logic [HEADER_BITS-1:0] header_r;
    logic [BEAT_COUNT_W-1:0] beat_counter_r;
    logic got_header_r;

    assign config_ready = 1'b1;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            header_r       <= '0;
            beat_counter_r <= '0;
            got_header_r   <= 1'b0;
        end else if (config_valid && config_ready && !got_header_r) begin
            header_r[beat_counter_r*BUS_WIDTH +: BUS_WIDTH] <= config_data;
            if (beat_counter_r == HEADER_BEATS-1) begin
                beat_counter_r <= '0;
                got_header_r   <= 1'b1;
            end else begin
                beat_counter_r <= beat_counter_r + 1'b1;
            end
        end
    end

    logic [7:0]  msg_type;
    logic [7:0]  layer_id;
    logic [15:0] layer_inputs;
    logic [15:0] num_neurons;
    logic [15:0] bytes_per_neuron;
    logic [31:0] total_bytes;
    logic [31:0] reserved;

    assign msg_type         = header_r[7:0];
    assign layer_id         = header_r[15:8];
    assign layer_inputs     = header_r[31:16];
    assign num_neurons      = header_r[47:32];
    assign bytes_per_neuron = header_r[63:48];
    assign total_bytes      = header_r[95:64];
    assign reserved         = header_r[127:96];
    
    
    endmodule*/

module config_manager #(
    parameter int BUS_WIDTH      = 64,
    parameter int BEAT_WIDTH     = 16,
    parameter int POPCOUNT_WIDTH = 32,
    parameter int L1_INPUTS      = 256,
    parameter int L1_NEURONS     = 256,
    parameter int L2_NEURONS     = 256,
    parameter int L3_NEURONS     = 10
)(
    input  logic clk,
    input  logic rst,

    input  logic [BUS_WIDTH-1:0]   config_data,
    input  logic [BUS_WIDTH/8-1:0] config_keep,
    input  logic                   config_valid,
    input  logic                   config_last,
    output logic                   config_ready,

    output logic                                                                          l1_w_wr_en,
    output logic [$clog2(L1_NEURONS * ((L1_INPUTS  + BEAT_WIDTH-1)/BEAT_WIDTH))-1:0]     l1_w_wr_addr,
    output logic [BEAT_WIDTH-1:0]                                                         l1_w_wr_data,

    output logic                                                                          l2_w_wr_en,
    output logic [$clog2(L2_NEURONS * ((L1_NEURONS + BEAT_WIDTH-1)/BEAT_WIDTH))-1:0]     l2_w_wr_addr,
    output logic [BEAT_WIDTH-1:0]                                                         l2_w_wr_data,

    output logic                                                                          l3_w_wr_en,
    output logic [$clog2(L3_NEURONS * ((L2_NEURONS + BEAT_WIDTH-1)/BEAT_WIDTH))-1:0]     l3_w_wr_addr,
    output logic [BEAT_WIDTH-1:0]                                                         l3_w_wr_data,

    output logic                                                                          l1_t_wr_en,
    output logic [$clog2(L1_NEURONS)-1:0]                                                 l1_t_wr_addr,
    output logic [POPCOUNT_WIDTH-1:0]                                                     l1_t_wr_data,

    output logic                                                                          l2_t_wr_en,
    output logic [$clog2(L2_NEURONS)-1:0]                                                 l2_t_wr_addr,
    output logic [POPCOUNT_WIDTH-1:0]                                                     l2_t_wr_data
);
    localparam int HEADER_BITS  = 128;
    localparam int HEADER_BEATS = (HEADER_BITS + BUS_WIDTH - 1) / BUS_WIDTH;
    localparam int HDR_BEAT_W   = (HEADER_BEATS <= 1) ? 1 : $clog2(HEADER_BEATS);

    localparam int W_RATIO      = BUS_WIDTH / BEAT_WIDTH;
    localparam int W_RATIO_W    = (W_RATIO <= 1) ? 1 : $clog2(W_RATIO);

    localparam int T_RATIO      = BUS_WIDTH / POPCOUNT_WIDTH;
    localparam int T_RATIO_W    = (T_RATIO <= 1) ? 1 : $clog2(T_RATIO);

    localparam int MAX_WR_WORDS = L1_NEURONS * ((L1_INPUTS + BEAT_WIDTH-1) / BEAT_WIDTH);
    localparam int WR_ADDR_W    = $clog2(MAX_WR_WORDS);
    localparam int T_ADDR_W     = $clog2(L1_NEURONS);

    localparam logic [7:0] MSG_WEIGHTS    = 8'h00;
    localparam logic [7:0] MSG_THRESHOLDS = 8'h01;

    logic [HEADER_BITS-1:0] header_r;
    logic [7:0]             msg_type;
    logic [7:0]             layer_id;
    logic [15:0]            layer_inputs;
    logic [15:0]            num_neurons;
    logic [15:0]            bytes_per_neuron;
    logic [31:0]            total_bytes;

    assign msg_type         = header_r[7:0];
    assign layer_id         = header_r[15:8];
    assign layer_inputs     = header_r[31:16];
    assign num_neurons      = header_r[47:32];
    assign bytes_per_neuron = header_r[63:48];
    assign total_bytes      = header_r[95:64];

    typedef enum logic [1:0] {
        S_HEADER,
        S_DRAIN_W,
        S_DRAIN_T
    } state_t;

    state_t state_r;

    logic [HDR_BEAT_W-1:0] hdr_beat_r;
    logic [BUS_WIDTH-1:0]  sr_r;
    logic [W_RATIO_W-1:0]  w_drain_r;
    logic [T_RATIO_W-1:0]  t_drain_r;
    logic [WR_ADDR_W-1:0]  wr_addr_r;
    logic [31:0]            bytes_left_r;
    logic                   sr_loaded_r;

    logic [BEAT_WIDTH-1:0]     w_drain_word;
    logic [POPCOUNT_WIDTH-1:0] t_drain_word;

    assign w_drain_word = sr_r[w_drain_r * BEAT_WIDTH     +: BEAT_WIDTH];
    assign t_drain_word = sr_r[t_drain_r * POPCOUNT_WIDTH +: POPCOUNT_WIDTH];

    logic w_drain_last, t_drain_last;
    assign w_drain_last = (w_drain_r == W_RATIO_W'(W_RATIO - 1));
    assign t_drain_last = (t_drain_r == T_RATIO_W'(T_RATIO - 1));

    // config_ready: high only when genuinely able to accept a beat
    // In S_HEADER: always ready
    // In S_DRAIN_W/T: only when SR is empty AND we are still in the
    //   drain state (state_r flop hasn't updated yet after last beat)
    always_comb begin
        case (state_r)
            S_HEADER:  config_ready = 1'b1;
            S_DRAIN_W: config_ready = !sr_loaded_r;
            S_DRAIN_T: config_ready = !sr_loaded_r;
            default:   config_ready = 1'b0;
        endcase
    end

    logic do_w_write, do_t_write;
    assign do_w_write = sr_loaded_r && (state_r == S_DRAIN_W);
    assign do_t_write = sr_loaded_r && (state_r == S_DRAIN_T);

    assign l1_w_wr_en   = do_w_write && (layer_id == 8'd0);
    assign l1_w_wr_addr = WR_ADDR_W'(wr_addr_r);
    assign l1_w_wr_data = w_drain_word;

    assign l2_w_wr_en   = do_w_write && (layer_id == 8'd1);
    assign l2_w_wr_addr = WR_ADDR_W'(wr_addr_r);
    assign l2_w_wr_data = w_drain_word;

    assign l3_w_wr_en   = do_w_write && (layer_id == 8'd2);
    assign l3_w_wr_addr = WR_ADDR_W'(wr_addr_r);
    assign l3_w_wr_data = w_drain_word;

    assign l1_t_wr_en   = do_t_write && (layer_id == 8'd0);
    assign l1_t_wr_addr = T_ADDR_W'(wr_addr_r);
    assign l1_t_wr_data = t_drain_word;

    assign l2_t_wr_en   = do_t_write && (layer_id == 8'd1);
    assign l2_t_wr_addr = T_ADDR_W'(wr_addr_r);
    assign l2_t_wr_data = t_drain_word;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state_r      <= S_HEADER;
            hdr_beat_r   <= '0;
            header_r     <= '0;
            sr_r         <= '0;
            sr_loaded_r  <= 1'b0;
            w_drain_r    <= '0;
            t_drain_r    <= '0;
            wr_addr_r    <= '0;
            bytes_left_r <= '0;
        end else begin
            case (state_r)

                S_HEADER: begin
                    if (config_valid) begin
                        header_r[hdr_beat_r * BUS_WIDTH +: BUS_WIDTH] <= config_data;
                        if (hdr_beat_r == HDR_BEAT_W'(HEADER_BEATS - 1)) begin
                            hdr_beat_r <= '0;
                            if (HEADER_BEATS == 1) begin
                                state_r      <= (config_data[7:0] == MSG_WEIGHTS) ? S_DRAIN_W : S_DRAIN_T;
                                bytes_left_r <= config_data[95:64];
                            end else begin
                                state_r      <= (header_r[7:0] == MSG_WEIGHTS) ? S_DRAIN_W : S_DRAIN_T;
                                bytes_left_r <= header_r[95:64];
                            end
                            wr_addr_r   <= '0;
                            sr_loaded_r <= 1'b0;
                        end else begin
                            hdr_beat_r <= hdr_beat_r + 1'b1;
                        end
                    end
                end

                S_DRAIN_W: begin
                    if (config_valid && config_ready) begin
                        sr_r        <= config_data;
                        sr_loaded_r <= 1'b1;
                        w_drain_r   <= '0;
                    end else if (sr_loaded_r) begin
                        if (w_drain_last) begin
                            sr_loaded_r  <= 1'b0;
                            w_drain_r    <= '0;
                            wr_addr_r    <= wr_addr_r + 1'b1;
                            bytes_left_r <= bytes_left_r - (BUS_WIDTH/8);
                            if (bytes_left_r == (BUS_WIDTH/8))
                                state_r <= S_HEADER;
                        end else begin
                            w_drain_r <= w_drain_r + 1'b1;
                            wr_addr_r <= wr_addr_r + 1'b1;
                        end
                    end
                end

                S_DRAIN_T: begin
                    if (config_valid && config_ready) begin
                        sr_r        <= config_data;
                        sr_loaded_r <= 1'b1;
                        t_drain_r   <= '0;
                    end else if (sr_loaded_r) begin
                        if (t_drain_last) begin
                            sr_loaded_r  <= 1'b0;
                            t_drain_r    <= '0;
                            wr_addr_r    <= wr_addr_r + 1'b1;
                            bytes_left_r <= bytes_left_r - (BUS_WIDTH/8);
                            if (bytes_left_r == (BUS_WIDTH/8))
                                state_r <= S_HEADER;
                        end else begin
                            t_drain_r <= t_drain_r + 1'b1;
                            wr_addr_r <= wr_addr_r + 1'b1;
                        end`
                    end
                end

            endcase
        end
    end

endmodule