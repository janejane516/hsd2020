`timescale 1ns / 1ps

module my_pe #(
        parameter L_RAM_SIZE = 4
    )
    (
        //clk, reset, (added) en
        input aclk,
        input aresetn,
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
        output [31:0] dout
    );
    //local register
    (* ram_style = "block" *) reg [31:0] peram [0:2**L_RAM_SIZE-1];
    //port B
    reg [31:0] bin;
    reg [31:0] psum;
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
                psum <= dout;
            end
	    else begin
               psum <= psum;
            end
        end
     end
    
    //assign dout = (dvalid == 1)? tmp: 1'b0;
    
    floating_point_MAC my_fp_MAC(
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_a_tvalid(valid),
        .s_axis_b_tvalid(valid),
        .s_axis_c_tvalid(valid),
        .s_axis_a_tdata(ain),
        .s_axis_b_tdata(bin),
        .s_axis_c_tdata(psum),
        .m_axis_result_tvalid(dvalid),
        .m_axis_result_tdata(dout)
    );
    
endmodule
