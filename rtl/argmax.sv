Assumptions: assume that the 10 neuron outputs are packed into an array and are attached to the neuron input for this 

module argmax #(
    NUM_OUTPUTS = 10, 
    COUNT_WIDTH = 32
)(
    input logic clk, 
    input logic rst, 
    input logic en, 
    input logic last,
    input logic [NUM_OUTPUTS-1:0] neuron_inputs, 
    output logic max_val
); 

    // use the reduction operator to get the current_winner_inx
    logic current_winner_inx = &neuron_inputs;
    logic last_in; 
    logic [NUM_OUTPUTS-1:0] big_ass_counter [COUNT_WIDTH-1]

    always_ff @(posedge clk or posedge rst) begin 
        if (rst // || start of new counter) begin 
            //
            for(int i = 0; i < NUM_INPUTS; i++) begin 
                big_ass_counter[i] <= COUNT_WIDTH'(0); 
            end 
        end else if (en) begin 
            big_ass_counter[current_winner_inx] <= big_ass_counter[current_winner_inx] + 1;
            if (last) last_in <= 1'b0; 
        end 
    end 

    if(last_in) begin 
        logic current_max_inx = 0; 
        for(int i = 0; i < COUNT_WIDTH; i++) begin 

        end 
    end 



endmodule
