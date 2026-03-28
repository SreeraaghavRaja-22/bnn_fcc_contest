// use a true dual-port (TDP) RAM that we're using for the threshold ram and weight
// this could improve the resource usage, for the moment I'll use a sdp ram

module ram_tdp #(
    parameter int DATA_WIDTH = 4, 
    parameter int ADDR_WIDTH = 8, 
    parameter int REG_RD_DATA = 1'b1; 
)