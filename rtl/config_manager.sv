module config_manager
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

endmodule