module neuron #(
	parameter NUM_WEIGHTS = 4,
	parameter NUM_INPUTS = 4,
	parameter THRESHOLD_BITS = 3
)
(
	input logic clk, 
	input logic rst, 
	input logic en, 
	input logic [NUM_WEIGHTS-1:0] w,
	input logic [NUM_INPUTS-1:0] x,
	input logic [THRESHOLD_BITS-1:0] threshold,
	output logic [$clog2(NUM_WEIGHTS+1)-1:0] y
);

	logic [NUM_INPUTS-1:0] xnor_out, xnor_out_r; 
	logic [$clog2(NUM_WEIGHTS+1)-1:0] count_ones_out, count_ones_out_r;
	logic w1_r, w2_r;

	assign xnor_out = w ~^ x;
	// assign count_ones_out = $countones(xnor_block_out); // popcount

	// adding the inputs and weights done here (pipeline this)

	always_ff @(posedge clk or posedge rst) begin // first implement with a basic pipeline 
		if (rst) begin
			xnor_out_r <= 1'b0;
		end
	end

	assign y = count_ones_out_r;

endmodule