`timescale 1ns / 1ps

module tb_my_pe(
    );
    parameter L_RAM_SIZE = 6;
    reg clk;
    reg rst;
    reg [31:0] ain;
    reg [31:0] din;
    reg [L_RAM_SIZE-1:0] addr;
    reg we;
    reg valid;
    wire dvalid;
    wire [31:0] dout;
    
    integer i;
    reg [31:0] global_buf[0:31];
    
    initial begin
        //generate test inputs and store them into 'global_buf'
        clk <= 0;
        rst <= 1;
        valid <= 0;
        #10;
        rst <= 0;
        for(i=0; i<32; i=i+1) begin
            global_buf[i] = $urandom; 
            global_buf[i] = {7'b0100000, global_buf[i][24:0]};
        end
        #10;
        //1. store 16 data to logcal register 'peram', from address 0 to 15.
        we <= 1;
        for(i=0; i<16; i=i+1) begin
            addr <= i;
            din <= global_buf[i];
            #10;
        end
        //2. PE get 16 new data, and perform MAC with data stored in 'peram'.
        addr <= 0;
        we <= 0;
        for(i=0; i<16; i=i+1) begin
            ain <= global_buf[i+16];
            addr <= i;
            #10;
            valid <= 1;
            #10;
            valid <= 0;
            wait(dvalid);
        end
    end
    
    always #5 clk = ~clk;
    
    my_pe MY_PE (
        .aclk(clk),
        .aresetn(~rst),
        .ain(ain),
        .din(din),
        .addr(addr),
        .we(we),
        .valid(valid),
        .dvalid(dvalid),
        .dout(dout)
    );
endmodule
