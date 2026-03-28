// ram for all the thresholds
// also will enable to be synthesized in vivado

module ram_sdp_vivado2 #(
    parameter int DATA_WIDTH  = 16, 
    parameter int ADDR_WIDTH  = 10, 
    parameter bit REG_RD_DATA = 1'b0, 
    parameter bit WRITE_FIRST = 1'b0, 
    parameter string STYLE = ""
)(
    input logic clk, 
    input logic rd_en,
    input logic [ADDR_WIDTH-1:0] rd_addr, 
    input logic [DATA_WIDTH-1:0] rd_data, 
    input logic wr_en, 
    input logic [ADDR_WIDTH-1:0] wr_addr, 
    input logic [DATA_WIDTH-1:0] wr_data
);

    // Deals with vivado support for different ram styles
    localparam int MAX_STYLE_LEN = 16; 
    typedef logic [MAX_STYLE_LEN*8-1:0] string_as_logic_t;
    localparam logic [MAX_STYLE_LEN*8-1:0] MEM_STYLE = string_as_logic_t'(STYLE);

    // used packed logic array in the attribute
    (* ram_style = MEM_STYLE *) logic [DATA_WIDTH-1:0] ram[2]