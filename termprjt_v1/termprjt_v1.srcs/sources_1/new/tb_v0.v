`timescale 1ns / 1ps

module tb_v0(
    );
    parameter BRAM_SIZE = 9;
    parameter V_SIZE = 16;
    reg start;
    reg reset;
    reg clk;
    reg [31:0] rddata;
    wire [8:0] rdaddr;
    wire done;
    wire we;
    wire [31:0] wrdata;
    
    integer i;
    reg [31:0] bram[0:V_SIZE**2+V_SIZE-1];
    
    initial begin
        clk <= 0;
        reset <= 1;
        start <= 0;
        #7;
        reset <= 0;
        for(i=0; i<(V_SIZE**2+V_SIZE); i=i+1) begin
            bram[i] = $urandom%(2**5);
            //bram[i] = {7'b0100000, bram[i][24:0]};
        end
        start <= 1;
        #10;
        start <= 0;
        #3;
        for(i=0; i<(V_SIZE**2+V_SIZE); i=i+1) begin
            rddata <= i;
            if(i==0) #15;
            else #20;
        end
    end
    
    always #5 clk = ~clk;
    
    pe_controller PE_CONTROLLER(
        .start(start),
        .aresetn(~reset),
        .aclk(clk),
        .rddata(rddata),
        .rdaddr(rdaddr),
        .done(done),
        .we(we),
        .wrdata(wrdata)
    );
endmodule