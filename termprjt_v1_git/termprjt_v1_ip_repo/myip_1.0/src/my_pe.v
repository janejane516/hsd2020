`timescale 1ns / 1ps

module my_pe #(
        parameter L_RAM_SIZE = 4
    )
    (
        //clk, reset, (added) en
        input aclk,
        input aresetn,
        input en,
        //port A
        input [31:0] ain,
        //peram -> port B
        input [31:0] din,
        input [L_RAM_SIZE-1:0] addr,
        input we,
        //integrated valid signal
        input valid,
        //computation result
        output dvalid,
        output reg [31:0] dout
    );
    //local register
    (* ram_style = "block" *) reg [31:0] peram [0:2**L_RAM_SIZE-1];
    //port B
    reg [31:0] bin;
    reg [31:0] psum;
    wire [31:0] tmp;
    integer i;
    
    always @(posedge aclk) begin
        if(~aresetn) begin
            psum <= 0;
        end
        else begin
            if(we == 1) begin
                peram[addr] <= din;
            end
            else begin
                bin <= peram[addr];
            end
            if(dvalid == 1) begin
                psum <= tmp;
            end
	        else begin
               psum <= psum;
            end
        end
     end
    
    reg [4:0] counter;
    localparam COUNT = 10;
    always @(posedge aclk) begin
        if(!aresetn) 
            counter <= 'd0;
        else begin
            if(valid)
                counter <= COUNT;
            else
                counter <= counter - 1;
        end
    end
    
    always @(posedge aclk) begin
        if(dvalid==1) 
            dout <= tmp;
        else
            dout <= dout;
    end
 
    assign dvalid = (counter == 0 && en)? 1'b1:1'b0;
    //assign dout = (dvalid == 1)? tmp: 1'b0;
    
    mymultadd MYmultadd(
        .CLK(aclk),
        .CE(1'b1),
        .SCLR(!aresetn),
        .A(ain),
        .B(bin),
        .C(psum),
        .SUBTRACT(1'b0),
        .P(tmp)
    );
    
endmodule
