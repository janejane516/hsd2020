`timescale 1ns / 1ps

module PE_controller2 #(
        parameter RAM_SIZE = 7,
        parameter BRAM_SIZE = 7
    )
    (
        input start,
        input reset,
        input clk,
        input [31:0] rddata,
        output [BRAM_SIZE-1:0] rdaddr,
        output done,
        output [31:0] out
    );
    reg [5:0] count31;
    reg [3:0] count15;
    reg [2:0] count4;
    reg counter_rst31, counter_rst15, counter_rst4;
    reg [1:0] present_state, next_state;
    reg pe_we, glob_we, pe_valid, pe_valid2, calc_start;
    wire pe_dvalid;
    wire [RAM_SIZE-1:0] pe_addr;
    wire [RAM_SIZE-1:0] glob_addr;
    reg [31:0] pe_ain, calc_out;
    wire [31:0] pe_dout;
    localparam S_IDLE = 2'd0, S_LOAD = 2'd1, S_CALC = 2'd2, S_DONE = 2'd3;
    
    // Global Buffer
    (* ram_style = "block" *) reg [31:0] glob_buf [0:2**RAM_SIZE-1];
    always @(posedge clk) begin
        if(glob_we == 1) glob_buf[glob_addr] <= rddata;
        else pe_ain <= glob_buf[glob_addr];
    end
    
    // PE
    my_pe #(.L_RAM_SIZE(RAM_SIZE)) MY_PE(
        .aclk(clk),.aresetn(~reset),.ain(pe_ain),.din(rddata),
        .addr(pe_addr),.we(pe_we),.valid(pe_valid),.dvalid(pe_dvalid), .dout(pe_dout)
    );
    
    // counter
    always @(posedge clk or posedge counter_rst31) begin
        if(counter_rst31) count31 <= 0; 
        else count31 <= count31 + 1;
    end
    
    always @(posedge clk or posedge counter_rst15) begin
        if(counter_rst15) begin
            count15 <= 0; pe_valid <= 0;
        end
        else begin
            if(pe_dvalid) begin
                count15 <= count15 + 1;
                pe_valid2 <= 1;
            end
            else pe_valid2 <= 0;   
        end
    end
    
    always @(posedge clk or posedge counter_rst4) begin
        if(counter_rst4) count4 <= 0;
        else count4 <= count4 + 1;
    end
    
    // input address 
    assign pe_addr = (present_state == S_LOAD && pe_we)? count31 
                      : (present_state == S_CALC && !pe_we)? count15 
                      : 0;
    assign glob_addr = (present_state == S_LOAD && glob_we)? (count31-16) 
                        : (present_state == S_CALC && !glob_we)? count15 
                        : 0;
                        
    // part 1: initialize to state S_IDLE and update present state register
    always @(posedge clk or posedge reset) begin
        if(reset) present_state <= S_IDLE;
        else present_state <= next_state;
    end
     
    // part 2: determine next state
    always @(*) begin
        case(present_state)
            S_IDLE: next_state = (start? S_LOAD : present_state);
            S_LOAD: next_state = ((count31 == 31)? S_CALC : present_state);
            S_CALC: next_state = ((count15 == 15 && pe_dvalid)? S_DONE : present_state);
            S_DONE: next_state = ((count4 == 4)? S_IDLE : present_state);
            default:begin end
        endcase
    end
                        
    
    // part 3: evaluate outputs
    // S_LOAD
    always @(*) begin
        case(present_state)
            S_LOAD:
                begin 
                    counter_rst31 <= 0;
                    if(count31 == 0) 
                        pe_we <= 1;
                    if(count31 == 16) begin
                        glob_we <= 1; pe_we <= 0;
                    end
                    if(count31 == 31)
                        calc_start <= 1;
                end
            default: counter_rst31 <= 1;
        endcase
    end 
    
    // S_CALC
    always @(*) begin
        case(present_state)
            S_CALC: 
                begin
                    counter_rst15 <= 0; glob_we <= 0;
                    if(calc_start) begin
                        pe_valid2 <= 1;
                        calc_start <= 0;
                    end
                    if(count15==15 && pe_dvalid)
                        calc_out <= pe_dout;
                end
            default: counter_rst15 <= 1;
        endcase
    end
    always @(posedge clk) begin
        if(present_state == S_CALC) pe_valid <= pe_valid2;
    end
    
    always @(*) begin
        case(present_state) 
            S_DONE:
                counter_rst4 <= 0;
            default:
                counter_rst4 <= 1;
        endcase
    end
    
    //output
    assign rdaddr = ((counter_rst31)? 'bz: count31);
    assign done = ((present_state == S_DONE)? 'b1: 'b0);
    assign out = (done? calc_out : 0);
    
endmodule
