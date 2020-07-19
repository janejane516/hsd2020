`timescale 1ns / 1ps

module tb_my_bram (
    );
    parameter BRAM_ADDR_WIDTH = 15;
    reg [BRAM_ADDR_WIDTH-1:0] BRAM_ADDR;
    reg BRAM_CLK;
    wire [31:0] BRAM_RDDATA1;
    wire [31:0] BRAM_RDDATA2;
    reg BRAM_EN1;
    reg BRAM_EN2;
    reg BRAM_RST;
    reg [3:0] BRAM_WE1;
    reg [3:0] BRAM_WE2;
    reg done1;
    reg done2;
    
    integer i;
    
    initial begin
        BRAM_CLK <= 0;
        BRAM_EN1 <= 0;
        BRAM_EN2 <= 0;
        BRAM_RST <= 0;
        done1 <= 0;
        done2 <= 0;
        #10;
        done1 <= 1;
        for(i=0; i<8192; i=i+1) begin
            BRAM_EN1 <= 1;
            BRAM_EN2 <= 0;
            BRAM_WE1 <= 4'b0;
            BRAM_ADDR <= {i, 2'b00};
            #30;
            BRAM_EN1 <= 0;
            BRAM_EN2 <= 1;
            BRAM_WE2 <= 4'b1111;
            #10;
        end
        BRAM_EN2 <= 0;
        done2 <= 1;
        #10;
        BRAM_RST <= 1;
        #10;
        BRAM_RST <= 0;
    end
    
    always #5 BRAM_CLK = ~BRAM_CLK;
    
    my_bram #(.INIT_FILE("input.txt"), .OUT_FILE("output1.txt")) BRAM1 
    (
        .BRAM_ADDR(BRAM_ADDR),
        .BRAM_CLK(BRAM_CLK),
        .BRAM_WRDATA(32'b0),
        .BRAM_RDDATA(BRAM_RDDATA1),
        .BRAM_EN(BRAM_EN1),
        .BRAM_RST(BRAM_RST),
        .BRAM_WE(BRAM_WE1),
        .done(done1)
    );
    
    my_bram #(.INIT_FILE(""), .OUT_FILE("output2.txt")) BRAM2
    (
        .BRAM_ADDR(BRAM_ADDR),
        .BRAM_CLK(BRAM_CLK),
        .BRAM_WRDATA(BRAM_RDDATA1),
        .BRAM_RDDATA(BRAM_RDDATA2),
        .BRAM_EN(BRAM_EN2),
        .BRAM_RST(BRAM_RST),
        .BRAM_WE(BRAM_WE2),
        .done(done2)
    );
   
endmodule
