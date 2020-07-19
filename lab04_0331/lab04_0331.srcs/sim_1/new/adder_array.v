`timescale 1ns / 1ps

module adder_array(cmd, ain0, ain1, ain2, ain3, bin0, bin1, bin2, bin3, dout0, dout1, dout2, dout3, overflow);
    input [2:0] cmd;
    input [31:0] ain0, ain1, ain2, ain3;
    input [31:0] bin0, bin1, bin2, bin3;
    output [31:0] dout0, dout1, dout2, dout3;
    output [3:0] overflow;
    
    wire [31:0] ain[3:0];
    wire [31:0] bin[3:0];
    wire [31:0] dout[3:0];
    
    assign {ain[0], ain[1], ain[2], ain[3]} = {ain0, ain1, ain2, ain3};
    assign {bin[0], bin[1], bin[2], bin[3]} = {bin0, bin1, bin2, bin3};
    assign {dout0, dout1, dout2, dout3} = {dout[0], dout[1], dout[2], dout[3]};
    
    genvar i;
    wire [3:0] chk;
    
    generate for(i=0; i<=3; i=i+1) begin:adder
        assign chk[i] = (cmd == i || cmd[2]);
        my_add MY_ADD(.ain(chk[i]? ain[i]:0), .bin(chk[i]? bin[i]:0), .dout(dout[i]), .overflow(overflow[i]));
    end endgenerate
    
       
endmodule
