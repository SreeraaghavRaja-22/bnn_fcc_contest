module neuron #(
	parameter NUM_WEIGHTS = 67,
	parameter NUM_INPUTS = 67,
	parameter THRESHOLD_BITS = 32
)
(
	input logic [NUM_WEIGHTS-1:0] w,
	input logic [NUM_INPUTS-1:0] x,
	input logic [THRESHOLD_BITS-1:0] threshold
);

	logic [NUM_WEIGHTS-1:0] xnor_block_out;
	logic [$clog2(NUM_WEIGHTS+1)-1:0] count_ones_out;

	assign xnor_block_out = w ~^ x;
	assign count_ones_out = $countones(xnor_block_out);

	always_comb begin 
		
	end

endmodule