module threshold_mem #(
    parameter ADDR_WIDTH = 8, // 256 Neurons
    parameter DATA_WIDTH = 16, // 16-bit precision
    parameter RAM_STYLE = "distributed" 
)(
    input logic clk, 
    input logic we, 
    input logic [ ADDR_WIDTH-1:0] addr, 
    input logic [ DATA_WIDTH-1:0] din, 
    output logic [DATA_WIDTH-1:0] dout
);

    // Build the memory in a specific style 
    (* ram_style = RAM_STYLE *)
    logic [DATA_WIDTH-1:0] mem [2**ADDR_WIDTH-1:0];

    // Sync Write / Asynchronous Read
    always_ff @(posedge clk) begin
        if (we) begin 
            mem[addr] <= din;
        end
    end

    assign dout = mem[addr];
endmodule