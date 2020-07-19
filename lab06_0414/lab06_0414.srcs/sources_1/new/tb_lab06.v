`timescale 1ns / 1ps

module tb_lab06(
    );
    parameter BRAM_SIZE = 5;
    reg start;
    reg reset;
    reg clk;
    reg [31:0] rddata;
    wire [BRAM_SIZE-1:0] rdaddr;
    wire done;
    
    integer i;
    reg [31:0] bram[0:31];
    
    initial begin
        clk <= 0;
        reset <= 1;
        start <= 0;
        #10;
        reset <= 0;
        for(i=0; i<32; i=i+1) begin
            bram[i] = $urandom;
            bram[i] = {7'b0100000, bram[i][24:0]};
        end
        start <= 1;
        #5;
        start <= 0;
        for(i=0; i<32; i=i+1) begin
            rddata <= bram[i];
            #10;
        end
    end
    
    always #5 clk = ~clk;
    
    PE_controller2 #(.RAM_SIZE(4), .BRAM_SIZE(BRAM_SIZE))PE_CONTROLLER(
        .start(start),
        .reset(reset),
        .clk(clk),
        .rddata(rddata),
        .rdaddr(rdaddr),
        .done(done)
    );
endmodule
