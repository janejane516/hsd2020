`timescale 1ns / 1ps

module my_fusedmult#(
        parameter BITWIDTH = 32
    )
    (
        input [BITWIDTH-1:0] ain,
        input [BITWIDTH-1:0] bin,
        input en,
        input clk,
        output [2*BITWIDTH-1:0] dout
    );
    
    wire [2*BITWIDTH-1:0] mul_out, sum;
    reg [2*BITWIDTH-1:0] tmp;
       
    always @(posedge clk) begin
        if (en == 0) begin
            tmp <= 0;
        end
        else begin
            tmp <= sum;
        end
    end
    
    assign dout = tmp;
    
    my_mul #(BITWIDTH) MY_MUL(.ain(ain), .bin(bin), .dout(mul_out));
    my_add #(2*BITWIDTH) MY_ADD(.ain(dout), .bin(mul_out), .dout(sum));  
    
endmodule
