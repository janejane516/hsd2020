`timescale 1ns / 1ps

module tb_int_MAC();
    reg [32-1:0] ain;
    reg [32-1:0] bin;
    reg [64-1:0] cin;
    reg rst;
    reg clk;
    wire [64-1:0] result;
    
    integer i;
    initial begin
        clk <= 0;
        rst <= 0;
        for(i=0; i<32; i=i+1) begin
            ain = $urandom%(2**5);
            bin = $urandom%(2**5);
            cin = $urandom%(2**6);
            #80;
        end
    end
    
    always #5 clk = ~clk;
    
    int_MAC INT_MAC(
        .CLK(clk),
        .CE(1'b1),
        .SCLR(rst),
        .A(ain),
        .B(bin),
        .C(cin),
        .SUBTRACT(1'b0),
        .P(result)
    );
endmodule
