`timescale 1ns/100ps

module argmax_tb;

    localparam int NUM_TESTS;
    localparam int COUNT_WIDTH = 32;
    localparam int NUM_OUTPUTS = 10;
    logic clk = 1'b0;
    logic rst;
    logic en;
    logic last;
    logic [NUM_OUTPUTS-1:0] neuron_inputs;
    logic max_val;

    // initialize the DUT
    argmax (.NUM_TESTS(NUM_TESTS), .COUNT_WIDTH(COUNT_WIDTH)) dut (.*);

    initial begin : generate_clk
        forever #5 clk <= ~clk; 
    end 

    initial begin : generate_stim; 

        // reset errything
        rst     <= 1'b1; 
        en      <= 1'b1; 
        last    <= 1'b0;
        repeat(10) @(posedge clk);
        @(negedge clk);
        rst <= 1'b0; 
        @(posedge clk);

        $display("Test 1");
        for(int i = 0; i < NUM_TESTS; i++) begin
            neuron_inputs <= $urandom; 
            
        end


    end



