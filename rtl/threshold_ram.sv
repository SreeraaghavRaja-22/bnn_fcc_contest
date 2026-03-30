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
    (* ram_style = MEM_STYLE *) logic [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH]
    logic [DATA_WIDTH-1:0] rd_data_ram; 

    always_ff @(posedge clk) begin 
        if (wr_en) ram[wr_addr] <= wr_data; 
        if (rd_en) rd_data_ram  <= ram[rd_addr];
    end

    if(WRITE_FIRST) begin : l_write_first
        logic bypass_valid_r = 1'b0; 
        logic [DATA_WIDTH-1:0] bypass_data_r; 

        always_ff @(posedge clk) begin 
            if(rd_en && wr_en) bypass_data_r <= wr_data;
            if (rd_en) bypass_valid_r <= wr_en && rd_addr == wr_addr; 
        end

        if(REG_RD_DATA) begin : l_reg_rd_data
            always_ff @(posedge clk) if (rd_en) rd_data <= bypass_valid_r ? bypass_data_r : rd_data_ram; 
        end else begin : l_no_reg_rd_data
            assign rd_data = bypass_valid_r ? bypass_data_r : rd_data_ram; 
        end 
    end else begin : l_read_first 
        if (REG_RD_DATA) begin : l_reg_rd_data
            always_ff @(posedge clk) if (rd_en) rd_data <= rd_data_ram;
        end else begin : l_no_reg_rd_data 
            assign rd_data = rd_data_ram;
        end 
    end 
endmodule  
        