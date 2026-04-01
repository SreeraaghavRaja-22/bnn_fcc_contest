Assumptions: assume that the 10 neuron outputs are packed into an array and are attached to the neuron input for this 

module argmax #(
    NUM_OUTPUTS = 10, 
    COUNT_WIDTH = 32
)(
    input logic clk, 
    input logic rst, 
    input logic en, 
    input logic last,
    input logic [NUM-1:0] neuron_inputs, 
    output logic max_val
); 

    logic last_in; 
    logic [NUM_OUTPUTS-1:0] big_ass_counter [COUNT_WIDTH-1];
    logic current_max_inx;

    always_ff @(posedge clk or posedge rst) begin 
        if (rst || last_in) begin 
            for(int i = 0; i < NUM_INPUTS; i++) begin 
                big_ass_counter[i] <= COUNT_WIDTH'(0); 
            end 
        end else if (en) begin 
            for(int i = 0; i < NUM_INPUTS; i++) begin 
                if (neuron_inputs[i]) big_ass_counter[i] <= big_ass_counter[i] + 1;
            end
            if (last) last_in                   <= 1'b1;  
            if(last_in) begin 
                for(int i = 0; i < COUNT_WIDTH; i++) begin 
                    if(big_ass_counter[current_max_inx] > big_ass_counter[i]) current_max_inx = i; 
                end 
            end 
        end 
    end 

    if(last_in) begin 
        for(int i = 0; i < COUNT_WIDTH; i++) begin 
            if(big_ass_counter[current_max_inx]) current_max_inx = i;  > big_ass_counter[i];
        end 
    end 
    assign max_val = current_max_inx; 
endmodule
