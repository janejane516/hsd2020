`timescale 1ns / 1ps

module my_bram #(
        parameter integer BRAM_ADDR_WIDTH = 15, //4*8192
        parameter INIT_FILE = "input.txt",
        parameter OUT_FILE = "output.txt"
    )
    (
        input wire [BRAM_ADDR_WIDTH-1:0] BRAM_ADDR,
        input wire BRAM_CLK,
        input wire [31:0] BRAM_WRDATA,
        output reg [31:0] BRAM_RDDATA,
        input wire BRAM_EN,
        input wire BRAM_RST,
        input wire [3:0] BRAM_WE,
        input wire done
    );
    
    reg [31:0] mem[0:8191];
    wire [BRAM_ADDR_WIDTH-3:0] addr = BRAM_ADDR[BRAM_ADDR_WIDTH-1:2];
    reg [31:0] dout;
    
    //code for reading & writing
    initial begin
        if(INIT_FILE != "") begin
            //read data from INIT_FILE and store them into 'mem'
            $readmemh(INIT_FILE, mem);
        end
        wait(done) begin
            //write data stored in 'mem' into OUT_FILE
            $writememh(OUT_FILE, mem);
        end
    end
    
    //code for BRAM implementation
    
    genvar i;
    wire [31:0] WRDATA;
    reg [1:0] RD_NOW; 
    reg WR_NOW;
    reg [31:0] RD_WAITING;
    reg [31:0] WR_WAITING;
    reg [BRAM_ADDR_WIDTH-3:0] addr_WAITING;
    
    generate for(i=0; i<4; i=i+1) begin
        assign WRDATA[8*(i+1)-1:8*i] = (BRAM_WE[i] == 1)? BRAM_WRDATA[8*(i+1)-1:8*i] : 8'b0;
    end endgenerate   
    
    always @(posedge BRAM_CLK or BRAM_RST) begin
        if(BRAM_RST == 1) begin
            BRAM_RDDATA <= 0;
        end
        else begin
            if(RD_NOW[1] == 1) begin
                BRAM_RDDATA = dout;
                RD_NOW[1] = 0;
            end
            if(RD_NOW[0] == 1) begin
                dout = RD_WAITING;
                RD_NOW[0] = 0; RD_NOW[1] = 1;
            end
            if(WR_NOW == 1) begin
                mem[addr_WAITING] = WR_WAITING;
                WR_NOW = 0;
            end
            if(BRAM_EN == 1) begin
                if(BRAM_WE == 4'b0) begin
                    RD_WAITING = mem[addr];
                    RD_NOW[0] = 1;
                end
                else begin
                    addr_WAITING = addr; WR_WAITING = WRDATA;
                    WR_NOW = 1;
                end
            end
        end
    end
    
endmodule
