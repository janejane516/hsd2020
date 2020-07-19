`timescale 1ns / 1ps

module tb_lab04();

    reg [32-1:0] ain;
    reg [32-1:0] bin;
    reg [32-1:0] cin1;
    reg [32-1:0] cin2;
    reg rst;
    reg clk;
    wire [32-1:0] f_res;
    wire [64-1:0] i_res;
    wire dvalid;
    
    integer i;
    initial begin
        clk <= 0;
        rst <= 0;
        for(i=0; i<32; i=i+1) begin
            ain = $urandom%(2**31);
            bin = $urandom%(2**31);
            cin1 = $urandom%(2**31);
            cin2 = $urandom%(2**31);
            #20;
        end
    end
    
    always #5 clk = ~clk;
    
    floating_point_MAC UUT1(
        .aclk(clk),
        .aresetn(~rst),
        .s_axis_a_tvalid(1'b1),
        .s_axis_b_tvalid(1'b1),
        .s_axis_c_tvalid(1'b1),
        .s_axis_a_tdata(ain),
        .s_axis_b_tdata(bin),
        .s_axis_c_tdata(cin1),
        .m_axis_result_tvalid(dvalid),
        .m_axis_result_tdata(f_res)
    );
    
    int_MAC UUT2(
        .CLK(clk),
        .CE(1'b1),
        .SCLR(rst),
        .A(ain),
        .B(bin),
        .C({cin1, cin2}),
        .SUBTRACT(1'b0),
        .P(i_res)
    );
endmodule
